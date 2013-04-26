#import "BasecampNextAccount.h"
#import "OAuth2Token.h"

#define BASECAMP_NEXT_OAUTH_KEY @"ddb287c5f0f3d6ec0dbc0ee708a733b6506621d8"
#define BASECAMP_NEXT_OAUTH_SECRET @"32e106ca8eac91f0afc407d309ed436176f1bc3d"
#define BASECAMP_NEXT_REDIRECT @"feedsapp%3A%2F%2Fbasecampnext%2Fauth"

@implementation BasecampNextAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresAuth { return YES; }
+ (BOOL)requiresDomain { return NO; }
+ (BOOL)requiresUsername { return NO; }
+ (BOOL)requiresPassword { return NO; }
+ (NSString *)friendlyAccountName { return @"Basecamp"; }
+ (NSTimeInterval)defaultRefreshInterval { return 60; } // one minute
- (NSString *)iconPrefix { return @"Basecamp"; }

- (void)beginAuth {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://launchpad.37signals.com/authorization/new?client_id=%@&redirect_uri=%@&type=web_server",BASECAMP_NEXT_OAUTH_KEY, BASECAMP_NEXT_REDIRECT]];

    [[NSWorkspace sharedWorkspace] openURL:URL];
}

- (void)authWasFinishedWithURL:(NSURL *)url {
    DDLogInfo(@"GOT URL: %@", url);

    // We could get:
    // feedsapp://basecampnext/auth?code=b1233f3e
    // feedsapp://basecampnext/auth?error=access_denied
    
    NSString *query = [url query]; // code=xyz
    
    if (![query beginsWithString:@"code="]) {
        
        NSString *message = @"There was an error while authenticating with Basecamp. If this continues to persist, please choose \"Report a Problem\" from the Feeds status bar icon.";
        
        if ([query isEqualToString:@"error=access_denied"])
            message = @"Authorization was denied. Please try again.";
        
        [self.delegate account:self validationDidFailWithMessage:message field:AccountFailingFieldAuth];
        return;
    }
    
    NSArray *parts = [query componentsSeparatedByString:@"="];
    NSString *code = [parts objectAtIndex:1]; // xyz
  
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://launchpad.37signals.com/authorization/token?type=web_server&client_id=%@&redirect_uri=%@&client_secret=%@&code=%@",BASECAMP_NEXT_OAUTH_KEY,BASECAMP_NEXT_REDIRECT,BASECAMP_NEXT_OAUTH_SECRET,code]];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
    URLRequest.HTTPMethod = @"POST";

    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:NULL];
    [self.request addTarget:self action:@selector(tokenRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(tokenRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

- (void)tokenRequestComplete:(NSData *)data {

    NSString *error = nil;
    OAuth2Token *token = [[OAuth2Token alloc] initWithTokenResponse:data error:&error];
    
    if (token) {
        [self validateWithPassword:token.stringRepresentation];
    }
    else {
        NSString *message = [NSString stringWithFormat:@"There was an error while authenticating with Basecamp: \"%@\"", error];
        [self.delegate account:self validationDidFailWithMessage:message field:AccountFailingFieldAuth];
    }
}

- (void)tokenRequestError:(NSError *)error {
    [self.delegate account:self validationDidFailWithMessage:@"There was an error while authenticating with Basecamp. If this continues to persist, please choose \"Report a Problem\" from the Feeds status bar icon." field:AccountFailingFieldAuth];
}

- (void)validateWithPassword:(NSString *)password {

    NSString *URL = @"https://launchpad.37signals.com/authorization.json";
    OAuth2Token *token = [OAuth2Token tokenWithStringRepresentation:password];
    
    NSURLRequest *URLRequest = [NSURLRequest requestWithURLString:URL OAuth2Token:token];
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:password];
    [self.request addTarget:self action:@selector(authorizationRequestComplete:password:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(handleGenericError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

- (void)authorizationRequestComplete:(NSData *)data password:(NSString *)password {
    
    NSDictionary *response = [data objectFromJSONData];
    
    NSDictionary *identity = [response objectForKey:@"identity"];
    NSString *author = [[identity objectForKey:@"id"] stringValue];
    
    // update our "username" with our email - this will cause our account to look nice in the list.
    self.username = [identity objectForKey:@"email_address"];
    
    NSArray *accounts = [response objectForKey:@"accounts"];
    
    NSMutableArray *foundFeeds = [NSMutableArray array];

    for (NSDictionary *account in accounts) {
        
        NSString *product = [account objectForKey:@"product"];
        if ([product isEqualToString:@"bcx"]) { // basecamp next

            NSString *accountName = [account objectForKey:@"name"];
            NSString *accountIdentifier = [account objectForKey:@"id"];            
            NSString *accountFeedString = [NSString stringWithFormat:@"https://basecamp.com/%@/api/v1/events.json", accountIdentifier];
            
            Feed *feed = [Feed feedWithURLString:accountFeedString title:accountName author:author account:self];
            feed.incremental = YES;
            feed.requiresOAuth2Token = YES;
            [foundFeeds addObject:feed];
        }
    }
    
    self.feeds = foundFeeds;
    
    [self.delegate account:self validationDidCompleteWithNewPassword:password];
}

- (void)handleGenericError:(NSError *)error {
    [self.delegate account:self validationDidFailWithMessage:@"Could not retrieve information about the given Basecamp account. If this continues to persist, please choose \"Report a Problem\" from the Feeds status bar icon." field:0];
}

#pragma mark Refreshing Feeds and Tokens

- (void)actualRefreshFeeds {
    for (Feed *feed in self.enabledFeeds) {
        
        NSURL *URL = feed.URL;
        
        // if the feed has items already, append since= to the URL so we only get new ones.
        FeedItem *latestItem = feed.items.firstObject;
        
        if (latestItem) {
            NSDateFormatter *formatter = [NSDateFormatter new];
            [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZ"];
            [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"America/Chicago"]];
            NSString *chicagoDate = [formatter stringFromDate:latestItem.published];
            
            URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?since=%@",URL.absoluteString,chicagoDate]];
        }
        
        [feed refreshWithURL:URL];
    }
}

- (void)refreshFeeds:(NSArray *)feedsToRefresh {

    if (([NSDate timeIntervalSinceReferenceDate] - self.lastTokenRefresh.timeIntervalSinceReferenceDate) > 60*60*24) { // refresh token at least every 24 hours
        
        // refresh our access_token first.
        DDLogInfo(@"Refresh token for %@", self);
        
        NSString *password = self.findPassword;
        OAuth2Token *token = [OAuth2Token tokenWithStringRepresentation:password];
        
        NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://launchpad.37signals.com/authorization/token?type=refresh&client_id=%@&client_secret=%@&grant_type=refresh_token&refresh_token=%@", BASECAMP_NEXT_OAUTH_KEY,BASECAMP_NEXT_OAUTH_SECRET,token.refresh_token.stringByEscapingForURLArgument]];
        
        NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
        URLRequest.HTTPMethod = @"POST";
        
        self.tokenRequest = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:feedsToRefresh];
        [self.tokenRequest addTarget:self action:@selector(refreshTokenRequestComplete:feeds:) forRequestEvents:SMWebRequestEventComplete];
        [self.tokenRequest addTarget:self action:@selector(refreshTokenRequestError:) forRequestEvents:SMWebRequestEventError];
        [self.tokenRequest start];
    }
    else [self actualRefreshFeeds];
}

- (void)refreshTokenRequestComplete:(NSData *)data feeds:(NSArray *)feedsToRefresh {
    
    self.lastTokenRefresh = [NSDate date];
    
    NSString *password = self.findPassword;
    OAuth2Token *token = [OAuth2Token tokenWithStringRepresentation:password];
    NSString *error = nil;
    OAuth2Token *newToken = [[OAuth2Token alloc] initWithTokenResponse:data error:&error];

    if (newToken) {
        
        // absorb new token if necessary
        if (![newToken.access_token isEqualToString:token.access_token]) {
            token.access_token = newToken.access_token;
            [self savePassword:token.stringRepresentation];
            [Account saveAccountsAndNotify:NO]; // not a notification-worthy change
        }
        
        // NOW refresh feeds
        [self actualRefreshFeeds];
    }
    else DDLogError(@"NO TOKEN: %@", [data objectFromJSONData]);
}

- (void)refreshTokenRequestError:(NSError *)error {
    DDLogError(@"ERROR WHILE REFRESHING: %@", error);
}

#pragma mark Parsing Response

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password {
        
    OAuth2Token *token = [OAuth2Token tokenWithStringRepresentation:password];
    
    // first we have to know who *we* are, and our author ID is different for each basecamp account (of course).
    // so we'll look it up if needed.
    NSURL *authorLookup = [NSURL URLWithString:@"people/me.json" relativeToURL:request.request.URL];
    NSData *authorData = [self extraDataWithContentsOfURLRequest:[NSMutableURLRequest requestWithURL:authorLookup OAuth2Token:token]];
    NSDictionary *response = [authorData objectFromJSONData];
    NSString *authorIdentifier = [[response objectForKey:@"id"] stringValue];
    
    NSMutableArray *items = [NSMutableArray array];

    NSArray *events = [data objectFromJSONData];
    
    for (NSDictionary *event in events) {
        
        NSString *date = [event objectForKey:@"created_at"];
        NSDictionary *bucket = [event objectForKey:@"bucket"];
        NSDictionary *creator = [event objectForKey:@"creator"];
        NSString *creatorIdentifier = [[creator objectForKey:@"id"] stringValue];

        NSString *URL = [event objectForKey:@"url"];
        URL = [URL stringByReplacingOccurrencesOfString:@"/api/v1/" withString:@"/"];
        URL = [URL stringByReplacingOccurrencesOfString:@".json" withString:@""];

        FeedItem *item = [FeedItem new];
        item.rawDate = date;
        item.published = AutoFormatDate(date);
        item.updated = item.published;
        item.author = [creator objectForKey:@"name"];
        item.authoredByMe = [creatorIdentifier isEqualToString:authorIdentifier];
        item.content = [NSString stringWithFormat:@"%@ %@",item.author, [event objectForKey:@"summary"]];
        item.project = [bucket objectForKey:@"name"];
        item.link = [NSURL URLWithString:URL];
        [items addObject:item];
    }
    
    return items;
}

@end
