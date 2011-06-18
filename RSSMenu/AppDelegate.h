
@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, GrowlApplicationBridgeDelegate> {
    NSStatusItem *statusItem;
    NSMenu *menu;
    NSArray *feeds; // of RSSFeed
    NSMutableArray *allItems;
    NSTimer *refreshTimer;
}

@property (assign) IBOutlet NSMenu *menu;

@end
