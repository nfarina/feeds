#import "FeedItemView.h"

@implementation FeedItemView
@synthesize menuItem, item;

- (id)initWithFrame:(NSRect)frame {
    [super initWithFrame:frame];
    [self setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    return self;
}

- (void)dealloc {
    self.menuItem = nil;
    self.item = nil;
    [super dealloc];
}

- (void)setItem:(FeedItem *)value {
    [item release], item = [value retain];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
//    NSLog(@"DRAW RECT");
//    
//    if ([menuItem isHighlighted])
//        [[NSColor redColor] set];
//    
//    [@"Hello World" drawAtPoint:NSMakePoint(0, 0) withAttributes:nil];
//    
//    NSLog(@"Super: %@", [self superview]);
}

@end
