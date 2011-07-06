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
    [request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestComplete:(NSData *)data {
    NSLog(@"Complete! %@", [SMXMLDocument documentWithData:data error:NULL]);
    [self.delegate accountValidationDidComplete:self];
}

- (void)meRequestError:(NSError *)error {
    NSLog(@"Error! %@", [SMXMLDocument documentWithData:request.data error:NULL]);
    [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Basecamp account. Please check your domain, username, and password." field:0];
}

@end
