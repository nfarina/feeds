
@interface OAuth2Token : NSObject {
    NSString *access_token, *refresh_token;
}

@property (nonatomic, copy) NSString *access_token, *refresh_token;

- (id)initWithTokenResponse:(NSData *)responseData error:(NSString **)error;

- (NSString *)stringRepresentation;
+ (OAuth2Token *)tokenWithStringRepresentation:(NSString *)string;

@end
