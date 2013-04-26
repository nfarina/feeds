#import "AccountCell.h"

@implementation AccountCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {

	NSDictionary *dict = self.objectValue;
    NSString *iconPrefix = dict[@"iconPrefix"];
    NSString *name = dict[@"name"];
    NSString *username = dict[@"username"];
    NSImage *icon = [NSImage imageNamed:[iconPrefix stringByAppendingString:@"Account.tiff"]];

    if (!username.length)
        username = dict[@"domain"];

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

    NSFont *typeFont = [NSFont systemFontOfSize:name.length > 10 ? 12 : 13];
	NSDictionary *typeAttributes = @{NSForegroundColorAttributeName: typeColor, NSFontAttributeName: typeFont};

    NSRect typeRect = cellFrame;
    typeRect.origin.x += 36;
    typeRect.origin.y += 4;
    typeRect.size.width -= (36+9);
    typeRect.size.height = typeFont.pointSize + 4;
    
	[name drawWithRect:typeRect options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine attributes:typeAttributes];

    NSFont *userFont = [NSFont systemFontOfSize:11];
	NSDictionary *userAttributes = @{NSForegroundColorAttributeName: userColor, NSFontAttributeName: userFont};

    NSRect userRect = typeRect;
    userRect.origin.y += 16;

    [username drawWithRect:userRect options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine attributes:userAttributes];
}

@end
