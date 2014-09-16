#import "ScholicaAccount.h"

@implementation ScholicaAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
- (NSTimeInterval)refreshInterval { return 5*60; } // 5 minutes

- (void)validateWithPassword:(NSString *)password {

    NSString *URL = @"https://api.scholica.com/1.0/notifications/rss";
    
    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:self.username password:password] delegate:nil context:password];
    [self.request addTarget:self action:@selector(rssRequestComplete:password:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(rssRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

- (void)rssRequestComplete:(NSData *)data password:(NSString *)password {

    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:NULL];
    NSString *title = [document.root valueWithPath:@"channel.title"];
    NSString *author = [title stringByReplacingOccurrencesOfString:@"Scholica activity for " withString:@""];
    
    NSString *URL = @"https://api.scholica.com/1.0/notifications/rss";
    
    Feed *feed = [Feed feedWithURLString:URL title:@"My notifications" author:author account:self];
    feed.requiresBasicAuth = YES;
    self.feeds = @[feed];
    
    [self.delegate account:self validationDidCompleteWithNewPassword:password];
}

- (void)rssRequestError:(NSError *)error {
    if (error.code == 401)
        [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Scholica account. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

@end
