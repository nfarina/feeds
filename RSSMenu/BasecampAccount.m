#import "BasecampAccount.h"

@implementation BasecampAccount

- (void)dealloc {
    [super dealloc];
}

- (void)validateWithPassword:(NSString *)password {
  
    NSString *URL = [NSString stringWithFormat:@"https://%@.basecamphq.com/me.xml", domain];
    
    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:username password:password] delegate:nil context:NULL];
    [request addTarget:self action:@selector(meRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestComplete:(NSData *)data {
    
    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:NULL];
    
    NSString *firstName = [document.root valueWithPath:@"first-name"];
    NSString *lastName = [document.root valueWithPath:@"last-name"];
    NSString *token = [document.root valueWithPath:@"token"];
    
    NSString *mainFeedString = [NSString stringWithFormat:@"https://%@:%@@%@.basecamphq.com/feed/recent_items_rss", token, token, domain];
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString];
    
    if ([firstName length] > 0 && [lastName length] > 0)
        mainFeed.author = [NSString stringWithFormat:@"%@ %@.", firstName, [lastName substringToIndex:1]];
    
    self.feeds = [NSArray arrayWithObject:mainFeed];
    
    [self.delegate accountValidationDidComplete:self];
}

- (void)meRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Basecamp account. Please check your domain, username, and password." field:0];
}

@end
