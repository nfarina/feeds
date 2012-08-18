#import "GenericFeedAccount.h"

@implementation GenericFeedAccount

+ (void)load { [Account registerClass:self]; }
+ (NSString *)friendlyAccountName { return @"RSS/Atom Feed"; }
+ (BOOL)requiresDomain { return YES; }
+ (NSString *)domainLabel { return @"Feed URL:"; }
+ (NSString *)domainPrefix { return @""; }
+ (NSString *)domainSuffix { return @""; }
+ (NSString *)domainPlaceholder { return @"http://example.com/feed.rss"; }

- (void)validateWithPassword:(NSString *)password {

    NSURLRequest *URLRequest;
    
    // just try fetching the given feed
    if (username.length)
        URLRequest = [NSURLRequest requestWithURLString:domain username:username password:password];
    else
        URLRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:domain]];
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:NULL];
    [request addTarget:self action:@selector(feedRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(feedRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)feedRequestComplete:(NSData *)data {
    
    Feed *feed = [Feed feedWithURLString:domain title:@"All Items" account:self];

    if (username.length)
        feed.requiresBasicAuth = YES;
    
    self.feeds = [NSArray arrayWithObject:feed];
    
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)feedRequestError:(NSError *)error {
    
    NSLog(@"Error! %@", error);
    // if we got a 401, then we can try basic auth if we ask you for your username and password
    if (error.code == 401 && !username.length)
        [self.delegate account:self validationDidRequireUsernameAndPasswordWithMessage:@"This feed requires a username/password."];
    else if (error.code == 401 && username.length)
        [self.delegate account:self validationDidRequireUsernameAndPasswordWithMessage:@"Could not access the given feed. Please check your username and password."];
    else if (error.code == 404 && username.length)
        [self.delegate account:self validationDidFailWithMessage:@"Could not access the given feed. Please check the URL, username, or password." field:AccountFailingFieldUnknown];
    else if (error.code == 404)
        [self.delegate account:self validationDidFailWithMessage:@"Could not access the given feed. The server reports that the URL could not be found." field:AccountFailingFieldDomain];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

@end
