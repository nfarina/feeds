#import "NSAlert+Foreground.h"

@implementation NSAlert (Foreground)

- (NSInteger)runModalInForeground
{
	// Transform process from background to foreground
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	SetFrontProcess(&psn);
	
	return [self runModal];
}

@end
