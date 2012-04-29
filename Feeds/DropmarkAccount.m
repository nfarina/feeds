#import "DropmarkAccount.h"

@implementation DropmarkAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
+ (NSString *)usernameLabel { return @"Email Address:"; }

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = @"https://app.dropmark.com/activity.rss";
    
    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:username password:password] delegate:nil context:password];
    [request addTarget:self action:@selector(rssRequestComplete:password:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(rssRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)rssRequestComplete:(NSData *)data password:(NSString *)password {

    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:NULL];
    NSString *title = [document.root valueWithPath:@"channel.title"];
    NSString *author = [title stringByReplacingOccurrencesOfString:@"Dropmark activity for " withString:@""];
    
    NSString *URL = @"https://app.dropmark.com/activity.rss";
    
    Feed *feed = [Feed feedWithURLString:URL title:@"All Activity" author:author account:self];
    feed.requiresBasicAuth = YES;
    self.feeds = [NSArray arrayWithObject:feed];
    
    [self.delegate account:self validationDidCompleteWithNewPassword:password];
}

- (void)rssRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    if (error.code == 401)
        [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Dropmark account. Please check your email address and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

@end
