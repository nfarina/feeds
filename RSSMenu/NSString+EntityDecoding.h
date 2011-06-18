
@interface NSString (EntityDecoding)

// stringWithFormat and %C can't handle extended ASCII codes from 127 to 160; this function will handle both.
// (assuming it's a particular sort of old-school MS Windows-based encoding)
extern NSString* NSStringFromCharacterCode(int code);

// Decodes character entities as specified in HTML, e.g. "&quot;", "&emdash;", "&#160;", etc.
- (NSString *)stringByDecodingCharacterEntities;

// Takes the given string containing HTML and strips all HTML entities except P and BR which are turned into genuine linebreaks.
// As a side-effect, also condenses whitespace as you would expect from HTML.
- (NSString *)stringByFlatteningHTML;

// Compresses characters in the given set into single spaces.
- (NSString *)stringByCondensingSet:(NSCharacterSet *)set;

@end
