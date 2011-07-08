#import "NSView+PrintHierarchy.h"

@implementation NSView (PrintHierarchy)

+ (void)printViewHierarchy:(NSView *)view indent:(NSString *)indent {
	NSLog(@"%@%@ frame = (%f,%f,%f,%f)", indent, view, view.frame.origin.x, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
	
	indent = [indent stringByAppendingString:@" "];
	
	for(NSView *subview in [view subviews])
		[NSView printViewHierarchy:subview indent:indent];
}

- (void)printViewHierarchy {
	[NSView printViewHierarchy:self indent:@""];
}

@end
