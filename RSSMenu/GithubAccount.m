#import "GithubAccount.h"

@implementation GithubAccount

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
    NSString *URL = @"https://github.com/account/admin";
    
    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:username password:password] delegate:nil context:password];
    [request addTarget:self action:@selector(tokenRequestComplete:password:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(tokenRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)privateFeedRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Github account. Please check your username and password." field:0];
}

- (void)tokenRequestComplete:(NSData *)data password:(NSString *)password {
    
    NSString *html = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    NSString *pattern = @"API Token.*<code>([0-9a-f]+)</code>";
    NSString *token = [html stringByMatching:pattern options:RKLMultiline|RKLDotAll inRange:NSMakeRange(0, [html length]) capture:1 error:NULL];
    
    if ([token length]) {

        // Now look for organizations
        NSString *URL = @"https://github.com/api/v2/json/organizations";
        
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

    // Sample result: {"organizations":[{"gravatar_id":"a0c3a0214c5f9a5701e892255fb3d87f","type":"Organization","login":"spotlightmobile"}]}
    NSDictionary *dict = [data JSONValue];
    NSArray *orgs = [dict objectForKey:@"organizations"];
    
    NSString *mainFeedString = [NSString stringWithFormat:@"https://github.com/%@.private.atom?token=%@", username, token];
    
    NSMutableArray *foundFeeds = [NSMutableArray arrayWithObject:[Feed feedWithURLString:mainFeedString author:username]];

    for (NSDictionary *org in orgs) {
        
        NSString *orgName = [org objectForKey:@"login"];
        NSString *orgFeedString = [NSString stringWithFormat:@"https://github.com/organizations/%@/%@.private.atom?token=%@", orgName, username, token];
        [foundFeeds addObject:[Feed feedWithURLString:orgFeedString author:username]];
    }
    
    self.feeds = foundFeeds;
    
    [self.delegate accountValidationDidComplete:self];
}

- (void)orgRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    [self.delegate account:self validationDidFailWithMessage:@"Could not retrieve information about the given Github account. Please check your username and password." field:0];
}

@end
