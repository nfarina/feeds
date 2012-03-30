#import "BasecampNextAccount.h"

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

- (void)beginAuth {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://launchpad.37signals.com/authorization/new?client_id=%@&redirect_uri=%@&type=web_server",BASECAMP_NEXT_OAUTH_KEY, BASECAMP_NEXT_REDIRECT]];

    [[NSWorkspace sharedWorkspace] openURL:URL];
}

- (void)authWasFinishedWithURL:(NSURL *)url {
    NSLog(@"GOT URL: %@", url);

    // We could get:
    // feedsapp://basecampnext/auth?code=b1233f3e
    // feedsapp://basecampnext/auth?error=access_denied
    
    NSString *query = [url query]; // code=xyz
    
    if (![query beginsWithString:@"code="]) {
        
        NSString *message = @"There was an error while authenticating with Basecamp. Please try again later, or email support@feedsapp.com.";
        
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
    [request addTarget:self action:@selector(tokenRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(tokenRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)tokenRequestComplete:(NSData *)data {
    
    NSDictionary *response = [data objectFromJSONData];
    NSString *token = [response objectForKey:@"access_token"];
    
    if (token) {
        NSLog(@"TOKEN: %@", token);
        [self validateWithPassword:token];
    }
    else [self.delegate account:self validationDidFailWithMessage:@"There was an error while authenticating with Basecamp. Please try again later, or email support@feedsapp.com." field:AccountFailingFieldAuth];
}

- (void)tokenRequestError:(NSError *)error {
    [self.delegate account:self validationDidFailWithMessage:@"There was an error while authenticating with Basecamp. Please try again later, or email support@feedsapp.com." field:AccountFailingFieldAuth];
}

- (void)validateWithPassword:(NSString *)token {

    NSString *URL = [NSString stringWithFormat:@"https://basecamp.com/%@/api/v1/people/me.json", domain];
    
    NSURLRequest *URLRequest = [NSURLRequest requestWithURLString:URL OAuth2Token:token];
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:token];
    [request addTarget:self action:@selector(meRequestComplete:token:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestComplete:(NSData *)data token:(NSString *)token {

    NSDictionary *response = [data objectFromJSONData];
    NSString *author = [[response objectForKey:@"id"] stringValue]; // store author by unique identifier instead of name

    NSString *URL = [NSString stringWithFormat:@"https://basecamp.com/%@/api/v1/projects.json", domain];

    NSURLRequest *URLRequest = [NSURLRequest requestWithURLString:URL OAuth2Token:token];

    NSArray *context = [NSArray arrayWithObjects:token, author, nil];
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:context];
    [request addTarget:self action:@selector(projectsRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(projectsRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    if (error.code == 404)
        [self.delegate account:self validationDidFailWithMessage:@"Could not find the given Basecamp account. Please verify that your Account ID matches the number found in your browser's address bar." field:AccountFailingFieldDomain];
    else if (error.code == 500)
        [self.delegate account:self validationDidFailWithMessage:@"There was a problem signing in to the given Basecamp account. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

- (void)projectsRequestComplete:(NSData *)data context:(NSArray *)context {
    
    NSString *token = [context objectAtIndex:0];
    NSString *author = [context objectAtIndex:1];
    
    NSArray *projects = [data objectFromJSONData];
    
    NSString *mainFeedString = [NSString stringWithFormat:@"https://basecamp.com/%@/api/v1/events.json", domain];
    NSString *mainFeedTitle = @"All Events";
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:mainFeedTitle author:author account:self];
    mainFeed.requiresOAuth2 = YES;
    
    NSMutableArray *foundFeeds = [NSMutableArray arrayWithObject:mainFeed];
    
    for (NSDictionary *project in projects) {
        
        NSString *projectName = [project objectForKey:@"name"];
        NSString *projectIdentifier = [project objectForKey:@"id"];
        NSString *projectFeedString = [NSString stringWithFormat:@"https://basecamp.com/%@/api/v1/projects/%@/events.json", domain, projectIdentifier];
        NSString *projectFeedTitle = [NSString stringWithFormat:@"Events for project \"%@\"", projectName];
        Feed *projectFeed = [Feed feedWithURLString:projectFeedString title:projectFeedTitle author:author account:self];
        projectFeed.requiresOAuth2 = YES;
        projectFeed.disabled = YES; // disable by default, only enable All Events
        [foundFeeds addObject:projectFeed];
    }
    
    self.feeds = foundFeeds;
    
    [self.delegate account:self validationDidCompleteWithPassword:token];
}

- (void)projectsRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    [self.delegate account:self validationDidFailWithMessage:@"Could not retrieve information about the given Basecamp account. Please contact support@feedsapp.com." field:0];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password {
    if ([request.request.URL.host isEqualToString:@"basecamp.com"]) {
        
        NSMutableArray *items = [NSMutableArray array];

        NSArray *events = [data objectFromJSONData];
        
        for (NSDictionary *event in events) {
            
            NSString *date = [event objectForKey:@"created_at"];
            NSDictionary *bucket = [event objectForKey:@"bucket"];
            NSDictionary *creator = [event objectForKey:@"creator"];
            NSNumber *creatorIdentifier = [creator objectForKey:@"id"];
            
            FeedItem *item = [[FeedItem new] autorelease];
            item.rawDate = date;
            item.published = AutoFormatDate(date);
            item.updated = item.published;
            item.authorIdentifier = [creatorIdentifier stringValue];
            item.author = [creator objectForKey:@"name"];
            item.content = [event objectForKey:@"summary"];
            item.project = [bucket objectForKey:@"name"];
//            item.title = [NSString stringWithFormat:@"%@ %@", item.author, item.content];
            [items addObject:item];
        }
        
        return items;
    }
    else return nil;
}

@end
