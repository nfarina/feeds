#import "HighriseAccount.h"

@implementation HighriseAccount

+ (BOOL)requiresDomain { return YES; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
+ (NSString *)domainSuffix { return @".highrisehq.com"; }

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = [NSString stringWithFormat:@"https://%@.highrisehq.com/me.xml", domain];
    
    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:username password:password] delegate:nil context:NULL];
    [request addTarget:self action:@selector(meRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestComplete:(NSData *)data {
    
    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:NULL];
    //NSLog(@"Document: %@", document);

    NSString *name = [document.root valueWithPath:@"name"];
    NSString *token = [document.root valueWithPath:@"token"];

    NSString *firstName = nil, *lastName = nil;
    NSArray *parts = [name componentsSeparatedByString:@" "];
    
    if ([parts count] == 2) {
        firstName = [parts objectAtIndex:0];
        lastName = [parts objectAtIndex:1];
    }
    
    NSString *mainFeedString = [NSString stringWithFormat:@"https://%@:%@@%@.highrisehq.com/recordings.atom", token, token, domain];
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:@"Latest Activity" account:self];
    
    if ([firstName length] > 0 && [lastName length] > 0)
        mainFeed.author = [NSString stringWithFormat:@"%@ %@.", firstName, [lastName substringToIndex:1]];
    
    self.feeds = [NSArray arrayWithObject:mainFeed];
    
    [self.delegate accountValidationDidComplete:self];
}

- (void)meRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    if (error.code == 404)
        [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Highrise account. Please check your domain, username, and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

@end
