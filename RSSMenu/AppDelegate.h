
@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, GrowlApplicationBridgeDelegate> {
    NSStatusItem *statusItem;
    NSMenu *menu;
    NSArray *feeds; // of RSSFeed
    NSMutableArray *allItems;
    NSTimer *refreshTimer;
    Reachability *reachability;
}

@property (assign) IBOutlet NSMenu *menu;

@end
