#import "StatusItemView.h"

@implementation StatusItemView
@synthesize icon, highlighted;

- (id)initWithStatusItem:(NSStatusItem *)theStatusItem {
	if ([super initWithFrame:NSMakeRect(0, 0, 30, 22)]) {
		statusItem = [theStatusItem retain];
		//		[self setImage:[NSImage imageNamed:@"StatusItem.png"]];
	}
	return self;
}

- (void)dealloc {
    [super dealloc];
}

- (void)setIcon:(StatusItemIcon)value {
    icon = value;
    [self setNeedsDisplay:YES];
}

- (void)setHighlighted:(BOOL)value {
    highlighted = value;
    [self setNeedsDisplay:YES];
}

- (NSImage *)iconImage {
    switch (icon) {
        case StatusItemIconInactive: return [NSImage imageNamed:@"StatusItemInactive.png"];
        case StatusItemIconUnread: return [NSImage imageNamed:@"StatusItemUnread.png"];
        default: return [NSImage imageNamed:@"StatusItem.png"];
    }
}

- (void)drawRect:(NSRect)rect {

    [statusItem drawStatusBarBackgroundInRect:rect withHighlight:highlighted];
    
    NSImage *image = highlighted ? [NSImage imageNamed:@"StatusItemSelected.png"] : [self iconImage];
    
	NSRect srcRect = NSMakeRect(0, 0, [image size].width, [image size].height);
    
    CGRect canvasRect = NSRectToCGRect(rect);
    CGSize imageSize = NSSizeToCGSize(srcRect.size);
    CGRect dstRect = CGRectCenteredInside(canvasRect, imageSize);

	[image drawInRect:NSRectFromCGRect(dstRect) fromRect:srcRect operation:NSCompositeSourceOver fraction:1];
}

- (void) mouseDown:(NSEvent *)theEvent {
	//NSLog(@"MOUSE DOWN: %@", NSStringFromRect([[self window] frame]));
    [self toggleMenu];
	
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

- (void)toggleMenu {
    if (highlighted)
        [[statusItem menu] cancelTracking];
    else
        [statusItem performSelector:@selector(popUpStatusItemMenu:) withObject:[statusItem menu] afterDelay:0];
    
    self.highlighted = !self.highlighted;
}

@end
