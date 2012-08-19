#import "PreferencesController.h"
#import "StatusItemView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, GrowlApplicationBridgeDelegate, NSUserNotificationCenterDelegate, NSAlertDelegate> {
    IBOutlet NSMenu *menu;
    IBOutlet NSMenuItem *markAllItemsAsReadItem;
    NSStatusItem *statusItem;
    StatusItemView *statusItemView;
    NSMutableArray *allItems;
    NSTimer *refreshTimer, *checkUserNotificationsTimer;
    Reachability *reachability;
    PreferencesController *preferencesController;
    BOOL menuNeedsRebuild;
    NSMenuItem *lastHighlightedItem; // not retained
    DDHotKeyCenter *hotKeyCenter;
    DDFileLogger *fileLogger;
    
    // popover handling if we're on Lion
    NSTimer *popoverTimer;
    NSPopover *popover;
    NSMenuItem *shimItem;
}

- (IBAction)markAllItemsAsRead:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)reportBug:(id)sender;

@end
