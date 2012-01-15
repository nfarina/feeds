
@interface NSURLRequest (Authorization)

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)URL username:(NSString *)username password:(NSString *)password;
+ (NSMutableURLRequest *)requestWithURLString:(NSString *)URLString username:(NSString *)username password:(NSString *)password;

@end
