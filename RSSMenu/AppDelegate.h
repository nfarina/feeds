
@interface AppDelegate : NSObject <NSApplicationDelegate> {
    NSStatusItem *statusItem;
    NSMenu *menu;
}

@property (assign) IBOutlet NSMenu *menu;

@end
