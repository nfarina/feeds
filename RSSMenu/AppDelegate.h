#import "PreferencesController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, GrowlApplicationBridgeDelegate> {
    IBOutlet NSMenu *menu;
    NSStatusItem *statusItem;
    NSArray *feeds; // of RSSFeed
    NSMutableArray *allItems;
    NSTimer *refreshTimer;
    Reachability *reachability;
    PreferencesController *preferencesController;
}

- (IBAction)openPreferences:(id)sender;

@end
