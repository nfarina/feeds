#import "StatusItemView.h"

@implementation StatusItemView
@synthesize icon, highlighted;

- (id)initWithStatusItem:(NSStatusItem *)theStatusItem {
	if (self = [super initWithFrame:NSMakeRect(0, 0, 30, 22)]) {
		statusItem = [theStatusItem retain];
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
        case StatusItemIconInactive: return [NSImage imageNamed:@"StatusItemInactive.tiff"];
        case StatusItemIconUnread: return [NSImage imageNamed:@"StatusItemUnread.tiff"];
        default: return [NSImage imageNamed:@"StatusItem.tiff"];
    }
}

- (void)drawRect:(NSRect)rect {

    [statusItem drawStatusBarBackgroundInRect:rect withHighlight:highlighted];
    
    NSImage *image = highlighted ? [NSImage imageNamed:@"StatusItemSelected.tiff"] : [self iconImage];
    
	NSRect srcRect = NSMakeRect(0, 0, [image size].width, [image size].height);
    
    CGRect canvasRect = NSRectToCGRect(rect);
    CGSize imageSize = NSSizeToCGSize(srcRect.size);
    CGRect dstRect = CGRectCenteredInside(canvasRect, imageSize);

	[image drawInRect:NSRectFromCGRect(dstRect) fromRect:srcRect operation:NSCompositeSourceOver fraction:1];
}

- (void) mouseDown:(NSEvent *)theEvent {
    [self toggleMenu];
}

- (void)toggleMenu {
    if (highlighted)
        [[statusItem menu] cancelTracking];
    else
        [statusItem performSelector:@selector(popUpStatusItemMenu:) withObject:[statusItem menu] afterDelay:0];
    
    self.highlighted = !self.highlighted;
}

@end
