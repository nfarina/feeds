#import "DribbbleAccount.h"

@implementation DribbbleAccount

+ (BOOL)requiresUsername { return YES; }

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = [NSString stringWithFormat:@"http://dribbble.com/%@/activity/incoming.rss", username];
    
    self.request = [SMWebRequest requestWithURL:[NSURL URLWithString:URL] delegate:nil context:NULL];
    [request addTarget:self action:@selector(meRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestComplete:(NSData *)data {
    
    self.feeds = [NSArray arrayWithObjects:
                  [Feed feedWithURLString:[NSString stringWithFormat:@"http://dribbble.com/%@/activity/incoming.rss", username] account:self],
                  [Feed feedWithURLString:[NSString stringWithFormat:@"http://dribbble.com/%@/shots/following.rss", username] account:self],
                  nil];
    
    [self.delegate accountValidationDidComplete:self];
}

- (void)meRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    [self.delegate account:self validationDidFailWithMessage:@"Could not find the given Dribbble username." field:AccountFailingFieldUsername];
}

@end
