
@interface NSURLRequest (Authorization)

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)URL username:(NSString *)username password:(NSString *)password;
+ (NSMutableURLRequest *)requestWithURLString:(NSString *)URLString username:(NSString *)username password:(NSString *)password;

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)URL OAuth2Token:(NSString *)token;
+ (NSMutableURLRequest *)requestWithURLString:(NSString *)URLString OAuth2Token:(NSString *)token;

@end
