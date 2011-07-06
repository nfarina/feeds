#import "PreferencesController.h"
#import "StatusItemView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, GrowlApplicationBridgeDelegate> {
    IBOutlet NSMenu *menu;
    NSStatusItem *statusItem;
    StatusItemView *statusItemView;
    NSMutableArray *allItems;
    NSTimer *refreshTimer;
    Reachability *reachability;
    PreferencesController *preferencesController;
}

- (IBAction)openPreferences:(id)sender;

@end
