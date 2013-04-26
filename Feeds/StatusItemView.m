#import "StatusItemView.h"

@interface StatusItemView ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@end

@implementation StatusItemView

- (id)initWithStatusItem:(NSStatusItem *)theStatusItem {
	if (self = [super initWithFrame:NSMakeRect(0, 0, 30, 22)]) {
		self.statusItem = theStatusItem;
	}
	return self;
}


- (void)setIcon:(StatusItemIcon)value {
    _icon = value;
    [self setNeedsDisplay:YES];
}

- (void)setHighlighted:(BOOL)value {
    _highlighted = value;
    [self setNeedsDisplay:YES];
}

- (NSImage *)iconImage {
    switch (self.icon) {
        case StatusItemIconInactive: return [NSImage imageNamed:@"StatusItemInactive.tiff"];
        case StatusItemIconUnread: return [NSImage imageNamed:@"StatusItemUnread.tiff"];
        default: return [NSImage imageNamed:@"StatusItem.tiff"];
    }
}

- (void)drawRect:(NSRect)rect {

    [self.statusItem drawStatusBarBackgroundInRect:rect withHighlight:self.highlighted];
    
    NSImage *image = self.highlighted ? [NSImage imageNamed:@"StatusItemSelected.tiff"] : [self iconImage];
    
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
    if (self.highlighted)
        [[self.statusItem menu] cancelTracking];
    else
        [self.statusItem performSelector:@selector(popUpStatusItemMenu:) withObject:[self.statusItem menu] afterDelay:0];
    
    self.highlighted = !self.highlighted;
}

@end
