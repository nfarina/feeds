
@interface NSURLRequest (Authorization)

+ (NSURLRequest *)requestWithURL:(NSURL *)URL username:(NSString *)username password:(NSString *)password;
+ (NSURLRequest *)requestWithURLString:(NSString *)URLString username:(NSString *)username password:(NSString *)password;

@end
