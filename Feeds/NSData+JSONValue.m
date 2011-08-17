#import "NSData+JSONValue.h"
#import "JSON.h"

@implementation NSData (JSONValue)

- (id)JSONValue {
	NSString *jsonString = [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
	id value = [jsonString JSONValue];
	[jsonString release];
	return value;
}

@end
