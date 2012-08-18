#import "NSString+Truncated.h"

@implementation NSString (Truncated)

- (NSString *)truncatedAfterIndex:(NSUInteger)index {
    return [self truncatedWithString:@"…" afterIndex:index];
}

- (NSString *)truncatedWithString:(NSString *)truncationString afterIndex:(NSUInteger)index {
    if (self.length > index) {
        
        // chop!
        NSString *truncated = [self substringToIndex:index];
        
        // make sure to clip any extra whitespace that may have been revealed after we chopped off the string
        truncated = [truncated stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        // add the truncation character, most likely an ellipsis
        return [truncated stringByAppendingString:truncationString];
    }
    else
        return self;
}

@end
