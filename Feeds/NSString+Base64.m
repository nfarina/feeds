#import "NSString+Base64.h"

@implementation NSString (Base64)

- (NSString *)base64EncodedString {  
    
    char *base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	NSMutableString *result = [[NSMutableString new] autorelease];
	int i;
	int len = (int)[self length];
	int paddingBytes = 0;
    
	for (i = 0; i < len; i+=3)
	{
		UInt32 threeBytes = [self characterAtIndex:i] * 0x10000;
        
		if (i < len - 1) threeBytes += [self characterAtIndex:i+1] * 0x100;
		else paddingBytes++;
        
		if (i < len - 2) threeBytes += [self characterAtIndex:i+2];
		else paddingBytes++;
        
		[result appendFormat:@"%c%c%c%c",
		 base64Chars[(threeBytes >> 18) & 0x3f],
		 base64Chars[(threeBytes >> 12) & 0x3f],
		 paddingBytes > 1 ? '=' : base64Chars[(threeBytes >> 6) & 0x3f],
		 paddingBytes > 0 ? '=' : base64Chars[ threeBytes       & 0x3f]];
	}
    
	return result;
}

@end  
