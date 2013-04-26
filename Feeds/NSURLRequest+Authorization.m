#import "NSURLRequest+Authorization.h"

@implementation NSURLRequest (Authorization)

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)URL username:(NSString *)username password:(NSString *)password {
    
    NSString *loginString = [NSString stringWithFormat:@"%@:%@", username, password];
    NSString *authHeader = [@"Basic " stringByAppendingString:[loginString base64EncodedString]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:URL];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    return request;
}

+ (NSMutableURLRequest *)requestWithURLString:(NSString *)URLString username:(NSString *)username password:(NSString *)password {
    return [self requestWithURL:[NSURL URLWithString:URLString] username:username password:password];
}

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)URL OAuth2Token:(OAuth2Token *)token; {
    
    NSString *authHeader = [@"Bearer " stringByAppendingString:token.access_token];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:URL];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    [request setValue:@"Feeds (http://feedsapp.com)" forHTTPHeaderField:@"User-Agent"]; // basecamp wants this for instance
    return request;
}

+ (NSMutableURLRequest *)requestWithURLString:(NSString *)URLString OAuth2Token:(OAuth2Token *)token; {
    return [self requestWithURL:[NSURL URLWithString:URLString] OAuth2Token:token];
}

@end
