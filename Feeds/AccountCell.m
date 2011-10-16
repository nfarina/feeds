#import "AccountCell.h"

@implementation AccountCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {

	NSDictionary *dict = self.objectValue;
    NSString *type = [dict objectForKey:@"type"];
    NSString *user = [dict objectForKey:@"username"];

    
    // We have to do some work otherwise the image will be drawn Y-flipped
	[[NSGraphicsContext currentContext] saveGraphicsState]; {
        
        float yOffset = cellFrame.origin.y;
        if ([controlView isFlipped]) {
            NSAffineTransform* transform = [NSAffineTransform transform];
            [transform translateXBy:0.0 yBy: cellFrame.size.height];
            [transform scaleXBy:1.0 yBy:-1.0];
            [transform concat];		
            yOffset = 0-cellFrame.origin.y;
        }	

        NSImage *icon = [NSImage imageNamed:[type stringByAppendingString:@"Account.png"]];
        [icon drawAtPoint:NSMakePoint(4, yOffset+6) fromRect:(NSRect){.size=icon.size} operation:NSCompositeSourceOver fraction:1];

	} [[NSGraphicsContext currentContext] restoreGraphicsState];	
	
    NSColor *typeColor, *userColor;
    
    if (self.isHighlighted && [self.controlView.window.firstResponder isEqual:self.controlView]) {
        typeColor = [NSColor alternateSelectedControlTextColor];
        userColor = typeColor;
    }
    else {
        typeColor = [NSColor textColor];
        userColor = [NSColor colorWithDeviceWhite:0.6 alpha:1];
    }

    NSFont *typeFont = [NSFont systemFontOfSize:13];
	NSDictionary *typeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:typeColor, NSForegroundColorAttributeName, typeFont, NSFontAttributeName, nil];

    NSRect typeRect = cellFrame;
    typeRect.origin.x += 36;
    typeRect.origin.y += 4;
    typeRect.size.width -= (36+9);
    typeRect.size.height = typeFont.pointSize + 4;
        
	[type drawWithRect:typeRect options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine attributes:typeAttributes];

    NSFont *userFont = [NSFont systemFontOfSize:11];
	NSDictionary *userAttributes = [NSDictionary dictionaryWithObjectsAndKeys:userColor, NSForegroundColorAttributeName, userFont, NSFontAttributeName, nil];

    NSRect userRect = typeRect;
    userRect.origin.y += 16;

    [user drawWithRect:userRect options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine attributes:userAttributes];
}

@end
