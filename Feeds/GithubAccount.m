#import "GithubAccount.h"

@implementation GithubAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = [NSString stringWithFormat:@"https://github.com/%@.private.atom", username];

    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:username password:password] delegate:nil context:password];
    [request addTarget:self action:@selector(privateFeedRequestComplete:password:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(privateFeedRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)privateFeedRequestComplete:(NSData *)data password:(NSString *)password {
    
    // OK your username is valid, now look for your API token
    NSString *URL = @"https://github.com/";
    
    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:username password:password] delegate:nil context:password];
    [request addTarget:self action:@selector(tokenRequestComplete:password:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(tokenRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)privateFeedRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    if (error.code == 401)
        [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Github account. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

- (void)tokenRequestComplete:(NSData *)data password:(NSString *)password {

    TFHpple *html = [[[TFHpple alloc] initWithHTMLData:data] autorelease];
    NSArray *links = [html searchWithXPathQuery:@"//link[@type='application/atom+xml']"];
    TFHppleElement *firstLink = links.firstObject;
    NSString *href = [firstLink.attributes objectForKey:@"href"];
    NSString *pattern = @"\\?token=([0-9a-f]+)";
    NSString *token = [href stringByMatching:pattern capture:1];
    
    if ([token length]) {

        // Now look for organizations
        NSString *URL = @"https://api.github.com/user/orgs";
        
        self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:username password:password] delegate:nil context:token];
        [request addTarget:self action:@selector(orgRequestComplete:token:) forRequestEvents:SMWebRequestEventComplete];
        [request addTarget:self action:@selector(orgRequestError:) forRequestEvents:SMWebRequestEventError];
        [request start];
        [delegate account:self validationDidContinueWithMessage:@"Finding feeds…"];
    }
    else {
        [self.delegate account:self validationDidFailWithMessage:@"Could not retrieve some information for the given Github account. Please check your username and password." field:0];
    }
}

- (void)tokenRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    [self.delegate account:self validationDidFailWithMessage:@"Could not retrieve information for the given Github account. Please check your username and password." field:0];
}

- (void)orgRequestComplete:(NSData *)data token:(NSString *)token {

    // Sample result: [{"avatar_url" = "...", id = 321558, login = spotlightmobile, url = "..."}]
    NSArray *orgs = [data objectFromJSONData];
    
    NSString *mainFeedString = [NSString stringWithFormat:@"https://github.com/%@.private.atom?token=%@", username, token];
    NSString *mainFeedTitle = [NSString stringWithFormat:@"News Feed (%@)", username];
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:mainFeedTitle author:username account:self];
    
    NSMutableArray *foundFeeds = [NSMutableArray arrayWithObject:mainFeed];

    for (NSDictionary *org in orgs) {
        
        NSString *orgName = [org objectForKey:@"login"];
        NSString *orgFeedString = [NSString stringWithFormat:@"https://github.com/organizations/%@/%@.private.atom?token=%@", orgName, username, token];
        NSString *orgFeedTitle = [NSString stringWithFormat:@"News Feed (%@)", orgName];
        [foundFeeds addObject:[Feed feedWithURLString:orgFeedString title:orgFeedTitle author:username account:self]];
    }
    
    self.feeds = foundFeeds;
    
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)orgRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    [self.delegate account:self validationDidFailWithMessage:@"Could not retrieve information about the given Github account. Please check your username and password." field:0];
}

@end
