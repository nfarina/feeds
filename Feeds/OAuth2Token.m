#import "OAuth2Token.h"

@implementation OAuth2Token

- (id)initWithTokenResponse:(NSData *)responseData error:(NSString **)error {
    if (self = [super init]) {
        
        NSDictionary *response = [responseData objectFromJSONData];
        self.access_token = [response objectForKey:@"access_token"];
        self.refresh_token = [response objectForKey:@"refresh_token"];
        
        (*error) = [response objectForKey:@"error"];
        if (*error) {
            return nil;
        }
        
        if (!self.access_token && !self.refresh_token) {
            *error = @"Token not found";
            return nil;
        }
    }
    return self;
}

- (NSString *)stringRepresentation {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          self.access_token, @"access_token",
                          self.refresh_token, @"refresh_token",
                          nil];
    return [dict JSONString];
}

+ (OAuth2Token *)tokenWithStringRepresentation:(NSString *)string {
    NSDictionary *dict = [string objectFromJSONString];
    
    if (dict) {
        OAuth2Token *token = [OAuth2Token new];
        token.access_token = [dict objectForKey:@"access_token"];
        token.refresh_token = [dict objectForKey:@"refresh_token"];
        return token;
    }
    else return nil;
}

@end
