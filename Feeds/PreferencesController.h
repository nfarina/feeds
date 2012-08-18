#import "NewAccountController.h"

#define DEFAULT_REFRESH_INTERVAL 30*60; // default to 30 minutes if none specified

typedef enum {
    NotificationTypeUserNotificationCenter = 0,
    NotificationTypeGrowl = 1,
    NotificationTypeDisabled = 2
} NotificationType;

@interface PreferencesController : NSWindowController <NSToolbarDelegate, NSTabViewDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, NewAccountControllerDelegate, AccountDelegate> {
    IBOutlet NSToolbar *toolbar;
    IBOutlet NSTabView *tabView;
    IBOutlet NSTableView *tableView, *feedsTableView;
    IBOutlet NSButton *removeButton, *launchAtStartupButton, *hideDockIconButton;
    IBOutlet NSPopUpButton *notificationTypeButton, *refreshIntervalButton;
    IBOutlet NSMenuItem *notificationTypeGrowlItem, *defaultRefreshIntervalItem, *oneMinuteRefreshIntervalItem;
    IBOutlet SRRecorderControl *keyRecorderControl;
    IBOutlet NSView *generalView, *accountsView;
    IBOutlet NSProgressIndicator *findFeedsProgress;
    IBOutlet NSTextField *findFeedsLabel, *accountNameLabel;
    IBOutlet NSImageView *findFeedsWarning;
    NSArray *oldFeeds;
}

+ (void)migrateSettings; // from an older version of Feeds

@property (nonatomic, copy) NSArray *oldFeeds;

- (id)initPreferencesController;
- (void)showPreferences;

- (IBAction)selectGeneralTab:(id)sender;
- (IBAction)selectAccountsTab:(id)sender;

- (IBAction)addAccount:(id)sender;
- (IBAction)removeAccount:(id)sender;

- (IBAction)notificationTypeChanged:(id)sender;
- (IBAction)launchAtStartupChanged:(id)sender;
- (IBAction)hideDockIconChanged:(id)sender;

- (IBAction)accountNameChanged:(id)sender;
- (IBAction)refreshIntervalChanged:(id)sender;

@end
