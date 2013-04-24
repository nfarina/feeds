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
    
    // OK your username is valid, now look for organizations
    NSString *URL = @"https://api.github.com/user/orgs";
    
    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:username password:password] delegate:nil context:nil];
    [request addTarget:self action:@selector(orgRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(orgRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
    [delegate account:self validationDidContinueWithMessage:@"Finding feeds…"];
}

- (void)privateFeedRequestError:(NSError *)error {
    if (error.code == 401)
        [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Github account. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

- (void)orgRequestComplete:(NSData *)data {

    // Sample result: [{"avatar_url" = "...", id = 321558, login = spotlightmobile, url = "..."}]
    NSArray *orgs = [data objectFromJSONData];
    
    NSString *mainFeedString = [NSString stringWithFormat:@"https://github.com/%@.private.atom", username];
    NSString *mainFeedTitle = [NSString stringWithFormat:@"News Feed (%@)", username];
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:mainFeedTitle author:username account:self];
    mainFeed.requiresBasicAuth = YES;
    
    NSMutableArray *foundFeeds = [NSMutableArray arrayWithObject:mainFeed];

    for (NSDictionary *org in orgs) {
        
        NSString *orgName = [org objectForKey:@"login"];
        NSString *orgFeedString = [NSString stringWithFormat:@"https://github.com/organizations/%@/%@.private.atom", orgName, username];
        NSString *orgFeedTitle = [NSString stringWithFormat:@"News Feed (%@)", orgName];
        Feed *orgFeed = [Feed feedWithURLString:orgFeedString title:orgFeedTitle author:username account:self];
        orgFeed.requiresBasicAuth = YES;
        [foundFeeds addObject:orgFeed];
    }
    
    self.feeds = foundFeeds;
    
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)orgRequestError:(NSError *)error {
    [self.delegate account:self validationDidFailWithMessage:@"Could not retrieve information about the given Github account. Please check your username and password." field:0];
}

@end
