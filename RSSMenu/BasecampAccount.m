#import "BasecampAccount.h"

@implementation BasecampAccount

- (void)dealloc {
    [super dealloc];
}

- (const char *)serviceName { return "Basecamp"; }

- (void)validate {
  
    NSString *URL = [NSString stringWithFormat:@"https://%@.basecamphq.com/me.xml", domain];
    
    NSString *loginString = [NSString stringWithFormat:@"%@:%@", username, password];  
    NSString *authHeader = [@"Basic " stringByAppendingString:[loginString base64EncodedString]];
    
    NSMutableURLRequest *URLRequest = [[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URL]] autorelease];
    [URLRequest setValue:authHeader forHTTPHeaderField:@"Authorization"];
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:NULL];
    [request addTarget:self action:@selector(meRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request start];
}

- (void)meRequestComplete:(NSData *)data {
    NSLog(@"Complete! %@", [SMXMLDocument documentWithData:data error:NULL]);
    [self.delegate accountValidationDidComplete:self];
}

@end
