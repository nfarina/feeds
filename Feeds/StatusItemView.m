#import "StatusItemView.h"

@interface StatusItemView ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@end

@implementation StatusItemView

- (id)initWithStatusItem:(NSStatusItem *)theStatusItem {
	if (self = [super initWithFrame:NSMakeRect(0, 0, 30, 22)]) {
		self.statusItem = theStatusItem;
        
        // use legacy NSViews for <10.10
        if (![self.statusItem respondsToSelector:@selector(button)])
            self.statusItem.view = self;
	}
	return self;
}


- (void)setIcon:(StatusItemIcon)value {
    _icon = value;
    
    // use proper NSStatusBarButtons on 10.10 and higher
    if ([self.statusItem respondsToSelector:@selector(button)]) {

        if (self.icon == StatusItemIconNormal) {
            NSImage *template = [NSImage imageNamed:@"StatusItemSelected"];
            [template setTemplate:YES];
            self.statusItem.button.image = template;
            self.statusItem.button.appearsDisabled = NO;
        }
        else if (self.icon == StatusItemIconUnread) {
            NSImage *template = [NSImage imageNamed:@"StatusItemUnread"];
            [template setTemplate:NO];
            self.statusItem.button.image = template;
            self.statusItem.button.appearsDisabled = NO;
        }
        else if (self.icon == StatusItemIconInactive) {
            NSImage *template = [NSImage imageNamed:@"StatusItemSelected"];
            [template setTemplate:YES];
            self.statusItem.button.image = template;
            self.statusItem.button.appearsDisabled = YES;
        }
    }
    else {
        [self setNeedsDisplay:YES];
    }
}

- (void)setHighlighted:(BOOL)value {
    _highlighted = value;
    [self setNeedsDisplay:YES];
}

- (NSImage *)iconImage {
    switch (self.icon) {
        case StatusItemIconInactive: return [NSImage imageNamed:@"StatusItemInactive"];
        case StatusItemIconUnread: return [NSImage imageNamed:@"StatusItemUnread"];
        default: return [NSImage imageNamed:@"StatusItem"];
    }
}

- (void)drawRect:(NSRect)rect {

    [self.statusItem drawStatusBarBackgroundInRect:rect withHighlight:self.highlighted];
    
    NSImage *image = self.highlighted ? [NSImage imageNamed:@"StatusItemSelected"] : [self iconImage];
    
	NSRect srcRect = NSMakeRect(0, 0, [image size].width, [image size].height);
    
    CGRect canvasRect = NSRectToCGRect(rect);
    CGSize imageSize = NSSizeToCGSize(srcRect.size);
    CGRect dstRect = CGRectCenteredInside(canvasRect, imageSize);

    // nudge it down as we adjusted our images upward for when displayed in NSStatusBarButton
    dstRect.origin.y -= 1;

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
