#import "PreferencesController.h"
#import "StatusItemView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, GrowlApplicationBridgeDelegate> {
    IBOutlet NSMenu *menu;
    NSStatusItem *statusItem;
    StatusItemView *statusItemView;
    NSMutableArray *allItems;
    NSTimer *refreshTimer;
    NSPopover *popover;
    Reachability *reachability;
    PreferencesController *preferencesController;
    
    NSMenuItem *shimItem;
}

- (IBAction)openPreferences:(id)sender;

@end
