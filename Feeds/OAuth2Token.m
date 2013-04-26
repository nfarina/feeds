#import "OAuth2Token.h"

@implementation OAuth2Token

- (id)initWithTokenResponse:(NSData *)responseData error:(NSString **)error {
    if (self = [super init]) {
        
        NSDictionary *response = [responseData objectFromJSONData];
        self.access_token = response[@"access_token"];
        self.refresh_token = response[@"refresh_token"];
        
        (*error) = response[@"error"];
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
    NSDictionary *dict = @{@"access_token": self.access_token,
                          @"refresh_token": self.refresh_token};
    return [dict JSONString];
}

+ (OAuth2Token *)tokenWithStringRepresentation:(NSString *)string {
    NSDictionary *dict = [string objectFromJSONString];
    
    if (dict) {
        OAuth2Token *token = [OAuth2Token new];
        token.access_token = dict[@"access_token"];
        token.refresh_token = dict[@"refresh_token"];
        return token;
    }
    else return nil;
}

@end
