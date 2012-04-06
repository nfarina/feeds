#import "DribbbleAccount.h"

@implementation DribbbleAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresUsername { return YES; }

- (NSTimeInterval)refreshInterval { return 15*60; } // 15 minutes to respect dribbble's request.

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = [NSString stringWithFormat:@"http://dribbble.com/%@/activity/incoming.rss", username];
    
    self.request = [SMWebRequest requestWithURL:[NSURL URLWithString:URL] delegate:nil context:NULL];
    [request addTarget:self action:@selector(meRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestComplete:(NSData *)data {
    
    self.feeds = [NSArray arrayWithObjects:
                  [Feed feedWithURLString:[NSString stringWithFormat:@"http://dribbble.com/%@/activity/incoming.rss", username] title:@"My Activity" account:self],
                  [Feed feedWithURLString:[NSString stringWithFormat:@"http://dribbble.com/%@/shots/following.rss", username] title:@"Following Activity" account:self],
                  nil];
    
    [self.delegate account:self validationDidCompleteWithPassword:nil];
}

- (void)meRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    if (error.code == 404)
        [self.delegate account:self validationDidFailWithMessage:@"Could not find the given Dribbble username." field:AccountFailingFieldUsername];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

@end
