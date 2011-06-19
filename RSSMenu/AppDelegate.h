#import "PreferencesController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, GrowlApplicationBridgeDelegate> {
    NSStatusItem *statusItem;
    NSMenu *menu;
    NSArray *feeds; // of RSSFeed
    NSMutableArray *allItems;
    NSTimer *refreshTimer;
    Reachability *reachability;
    PreferencesController *preferencesController;
}

@property (assign) IBOutlet NSMenu *menu;

- (IBAction)openPreferences:(id)sender;

@end
