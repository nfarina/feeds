#import "OAuth2Token.h"

@implementation OAuth2Token
@synthesize access_token, refresh_token;

- (id)initWithTokenResponse:(NSData *)responseData error:(NSString **)error {
    if (self = [super init]) {
        
        NSDictionary *response = [responseData objectFromJSONData];
        self.access_token = [response objectForKey:@"access_token"];
        self.refresh_token = [response objectForKey:@"refresh_token"];
        
        (*error) = [response objectForKey:@"error"];
        if (*error) {
            [self release];
            return nil;
        }
        
        if (!access_token && !refresh_token) {
            [self release];
            *error = @"Token not found";
            return nil;
        }
    }
    return self;
}

- (NSString *)stringRepresentation {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          access_token, @"access_token",
                          refresh_token, @"refresh_token",
                          nil];
    return [dict JSONString];
}

+ (OAuth2Token *)tokenWithStringRepresentation:(NSString *)string {
    NSDictionary *dict = [string objectFromJSONString];
    
    if (dict) {
        OAuth2Token *token = [[OAuth2Token new] autorelease];
        token.access_token = [dict objectForKey:@"access_token"];
        token.refresh_token = [dict objectForKey:@"refresh_token"];
        return token;
    }
    else return nil;
}

@end
