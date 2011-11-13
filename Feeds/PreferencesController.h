#import "NewAccountController.h"

@interface PreferencesController : NSWindowController <NSToolbarDelegate, NSTabViewDelegate, NSTableViewDataSource, NSTableViewDelegate, NewAccountControllerDelegate> {
    IBOutlet NSToolbar *toolbar;
    IBOutlet NSTabView *tabView;
    IBOutlet NSTableView *tableView;
    IBOutlet NSButton *removeButton;
    IBOutlet SRRecorderControl *keyRecorderControl;
    IBOutlet NSView *generalView, *accountsView;
}

- (id)initPreferencesController;
- (void)showPreferences;

- (IBAction)selectGeneralTab:(id)sender;
- (IBAction)selectAccountsTab:(id)sender;

- (IBAction)addAccount:(id)sender;
- (IBAction)removeAccount:(id)sender;

@end
