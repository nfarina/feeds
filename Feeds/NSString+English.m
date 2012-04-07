#import "NSString+English.h"

BOOL NSEqualStrings(NSString *aString, NSString *bString) {
    return (!aString && !bString) || [aString isEqualToString:bString];
}

BOOL NSEqualObjects(id a, id b) {
    return (!a && !b) || [a isEqual:b];
}

@implementation NSString (English)

- (NSString *)pluralizedForCount:(NSUInteger)count {
	if (count == 1)
		return self;
	else
		return [self stringByAppendingString:@"s"];
}

- (NSString *)stringByRemovingPrefix:(NSString *)prefix {
	if (self.length > prefix.length && [self rangeOfString:prefix options:NSCaseInsensitiveSearch].location == 0)
		return [self substringFromIndex:prefix.length];
	else
		return self;
}

- (BOOL)containsString:(NSString *)substring {
	return [self containsString:substring options:0];
}

- (BOOL)containsString:(NSString *)substring options:(NSStringCompareOptions)mask {
	return substring && [self rangeOfString:substring options:mask].location != NSNotFound;
}

- (BOOL)beginsWithString:(NSString *)substring {
	return [self beginsWithString:substring options:0];
}

- (BOOL)beginsWithString:(NSString *)substring options:(NSStringCompareOptions)mask {
	return substring && [self rangeOfString:substring options:mask].location == 0;
}

- (BOOL)endsWithString:(NSString *)substring {
	return [self endsWithString:substring options:0];
}

- (BOOL)endsWithString:(NSString *)substring options:(NSStringCompareOptions)mask {
	return substring && [self rangeOfString:substring options:mask].location == ([self length] - [substring length]);
}

@end
