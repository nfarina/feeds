#import "NSURLRequest+Authorization.h"

@implementation NSURLRequest (Authorization)

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)URL username:(NSString *)username password:(NSString *)password {
    
    NSString *loginString = [NSString stringWithFormat:@"%@:%@", username, password];
    NSString *authHeader = [@"Basic " stringByAppendingString:[loginString base64EncodedString]];
    
    NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:URL] autorelease];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    return request;
}

+ (NSMutableURLRequest *)requestWithURLString:(NSString *)URLString username:(NSString *)username password:(NSString *)password {
    return [self requestWithURL:[NSURL URLWithString:URLString] username:username password:password];
}

@end
