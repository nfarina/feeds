#import "NewAccountController.h"

#define DEFAULT_REFRESH_INTERVAL 30*60; // default to 30 minutes if none specified

@interface PreferencesController : NSWindowController <NSToolbarDelegate, NSTabViewDelegate, NSTableViewDataSource, NSTableViewDelegate, NewAccountControllerDelegate> {
    IBOutlet NSToolbar *toolbar;
    IBOutlet NSTabView *tabView;
    IBOutlet NSTableView *tableView;
    IBOutlet NSButton *removeButton, *showNotificationsButton, *launchAtStartupButton;
    IBOutlet SRRecorderControl *keyRecorderControl;
    IBOutlet NSView *generalView, *accountsView;
    IBOutlet NSPopUpButton *refreshIntervalButton;
}

- (id)initPreferencesController;
- (void)showPreferences;

- (IBAction)selectGeneralTab:(id)sender;
- (IBAction)selectAccountsTab:(id)sender;

- (IBAction)addAccount:(id)sender;
- (IBAction)removeAccount:(id)sender;

- (IBAction)refreshIntervalChanged:(id)sender;
- (IBAction)showNotificationsChanged:(id)sender;
- (IBAction)launchAtStartupChanged:(id)sender;

@end
