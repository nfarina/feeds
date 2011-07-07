
typedef enum {
    StatusItemIconNormal,
    StatusItemIconUnread,
    StatusItemIconInactive
} StatusItemIcon;

@interface StatusItemView : NSView {
	NSStatusItem *statusItem;
    BOOL highlighted;
    StatusItemIcon icon;
}

- (id)initWithStatusItem:(NSStatusItem *)statusItem;

- (void)toggleMenu;

@property (nonatomic, assign) StatusItemIcon icon;
@property (nonatomic, assign) BOOL highlighted;

@end
