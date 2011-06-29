#import "StatusItemView.h"

@implementation StatusItemView

- (id)initWithStatusItem:(NSStatusItem *)theStatusItem {
	if ([super initWithFrame:NSMakeRect(0, 0, 30, 22)]) {
		statusItem = [theStatusItem retain];
		//		[self setImage:[NSImage imageNamed:@"StatusItem.png"]];
	}
	return self;
}

- (void)drawRect:(NSRect)rect {
	
    [statusItem drawStatusBarBackgroundInRect:rect withHighlight:highlighted];
    
	//NSRect imageRect = NSOffsetRect(dirtyRect, 0, 1);
	//[[NSImage imageNamed:@"StatusItem.png"] drawInRect:imageRect fromRect:[self bounds] operation:NSCompositeSourceOver fraction:1];
}

- (void) mouseDown:(NSEvent *)theEvent {
	NSLog(@"MOUSE DOWN: %@", NSStringFromRect([[self window] frame]));
    
	
//	NSRect statusItemRect = [[self window] frame];

//	NSRect windowRect = [mainWindow frame];
//	
//	CGFloat x = roundf((statusItemRect.origin.x + statusItemRect.size.width/2) - (windowRect.size.width/2));
//	CGFloat y = statusItemRect.origin.y + 5;
//	
//	[mainWindow setFrameTopLeftPoint:NSMakePoint(x, y)];
//	[mainWindow makeKeyAndOrderFront:nil];
//	
	// Transform process from background to foreground
//	ProcessSerialNumber psn = { 0, kCurrentProcess };
//	SetFrontProcess(&psn);
}

@end
