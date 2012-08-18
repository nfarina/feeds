#import "PreferencesController.h"
#import "StatusItemView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, GrowlApplicationBridgeDelegate, NSUserNotificationCenterDelegate> {
    IBOutlet NSMenu *menu;
    IBOutlet NSMenuItem *markAllItemsAsReadItem;
    NSStatusItem *statusItem;
    StatusItemView *statusItemView;
    NSMutableArray *allItems;
    NSTimer *refreshTimer;
    Reachability *reachability;
    PreferencesController *preferencesController;
    BOOL menuNeedsRebuild;
    NSMenuItem *lastHighlightedItem; // not retained
    DDHotKeyCenter *hotKeyCenter;
    
    // popover handling if we're on Lion (have to use "id" to reference it so it doesn't crash on pre-Lion machines)
    NSTimer *popoverTimer;
    id popover;
    NSMenuItem *shimItem;
}

- (IBAction)markAllItemsAsRead:(id)sender;
- (IBAction)openPreferences:(id)sender;

@end
