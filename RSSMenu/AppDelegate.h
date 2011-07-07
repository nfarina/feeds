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
    BOOL menuNeedsRebuild;
    NSMenuItem *lastHighlightedItem; // not retained
    
    // popover handling if we're on Lion (have to use "id" to reference it so it doesn't crash on pre-Lion machines)
    NSTimer *popoverTimer;
    id popover;
    NSMenuItem *shimItem;
}

- (IBAction)openPreferences:(id)sender;

@end
