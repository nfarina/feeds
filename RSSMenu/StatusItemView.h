
@interface StatusItemView : NSView {
	NSStatusItem *statusItem;
    BOOL highlighted;
}

- (id)initWithStatusItem:(NSStatusItem *)statusItem;

@end
