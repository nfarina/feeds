
@interface AppDelegate : NSObject <NSApplicationDelegate> {
    NSStatusItem *statusItem;
    NSMenu *menu;
    NSArray *feeds; // of RSSFeed
}

@property (assign) IBOutlet NSMenu *menu;

@end
