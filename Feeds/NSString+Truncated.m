#import "NSString+Truncated.h"

@implementation NSString (Truncated)

- (NSString *)truncatedAfterIndex:(NSUInteger)index {
    return [self length] > index ? [[self substringToIndex:index] stringByAppendingString:@"…"] : self;
}

@end
