
BOOL NSEqualStrings(NSString *aString, NSString *bString);
BOOL NSEqualObjects(id a, id b);

@interface NSString (English)

// Appends an "s" to this word if count is greater than 1.
- (NSString *)pluralizedForCount:(NSUInteger)count;

// Removes the given prefix from this string, if it exists. Useful for removing "the " from strings before sorting.
- (NSString *)stringByRemovingPrefix:(NSString *)prefix;

// These should really be in the cocoa framework already. I mean, come on.
- (BOOL)containsString:(NSString *)substring;
- (BOOL)containsString:(NSString *)substring options:(NSStringCompareOptions)mask;
- (BOOL)containsCharacterFromSet:(NSCharacterSet *)set;
- (BOOL)containsCharacterFromSet:(NSCharacterSet *)set options:(NSStringCompareOptions)mask;
- (BOOL)beginsWithString:(NSString *)substring;
- (BOOL)beginsWithString:(NSString *)substring options:(NSStringCompareOptions)mask;
- (BOOL)endsWithString:(NSString *)substring;
- (BOOL)endsWithString:(NSString *)substring options:(NSStringCompareOptions)mask;

@end