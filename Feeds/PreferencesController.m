#import "PreferencesController.h"
#import "LoginItems.h"

@interface PreferencesController () <NSToolbarDelegate, NSTabViewDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, CreateAccountControllerDelegate, AccountDelegate>
@property (nonatomic, strong) IBOutlet NSToolbar *toolbar;
@property (nonatomic, strong) IBOutlet NSTabView *tabView;
@property (nonatomic, strong) IBOutlet NSTableView *tableView, *feedsTableView;
@property (nonatomic, strong) IBOutlet NSButton *removeButton, *launchAtStartupButton, *hideDockIconButton;
@property (nonatomic, strong) IBOutlet NSPopUpButton *notificationTypeButton, *refreshIntervalButton;
@property (nonatomic, strong) IBOutlet NSMenuItem *notificationTypeGrowlItem, *defaultRefreshIntervalItem, *oneMinuteRefreshIntervalItem;
@property (nonatomic, strong) IBOutlet SRRecorderControl *keyRecorderControl;
@property (nonatomic, strong) IBOutlet NSView *generalView, *accountsView;
@property (nonatomic, strong) IBOutlet NSProgressIndicator *findFeedsProgress;
@property (nonatomic, strong) IBOutlet NSTextField *findFeedsLabel, *accountNameLabel;
@property (nonatomic, strong) IBOutlet NSImageView *findFeedsWarning;
@property (nonatomic, copy) NSArray *oldFeeds;
@property (nonatomic, strong) CreateAccountController *createAccountController;
@end

@implementation PreferencesController

+ (void)migrateSettings {
    NotificationType notificationType = (NotificationType)[[NSUserDefaults standardUserDefaults] integerForKey:@"NotificationType"];
    
    // if you had disabled notifications in a previous version, we can migrate that setting
    BOOL disabledNotifications = [[NSUserDefaults standardUserDefaults] boolForKey:@"DisableNotifications"];
    if (disabledNotifications)
        notificationType = NotificationTypeDisabled;

    // remove this setting regardless
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DisableNotifications"];

    // Select Growl if User Notification Center was defaulted to but is not available
    if (!HAS_NOTIFICATION_CENTER && notificationType == NotificationTypeUserNotificationCenter) {
        notificationType = NotificationTypeGrowl;
        [[NSUserDefaults standardUserDefaults] setInteger:notificationType forKey:@"NotificationType"];
    }
}

- (id)initPreferencesController {
    if (self = [super initWithWindowNibName:@"PreferencesController"]) {
        // Initialization code here.
    }
    return self;
}

- (void)awakeFromNib {
    [self.toolbar setSelectedItemIdentifier:@"general"];
    [self selectGeneralTab:nil];
    [self tableViewSelectionDidChange:nil];
    
    // if we don't have Notification Center available (pre-mountain-lion) then we can't select it
    if (!HAS_NOTIFICATION_CENTER) {
        // hide the fact that Growl exists (you don't have a choice now)
        [self.notificationTypeButton removeItemAtIndex:0];
        self.notificationTypeGrowlItem.title = @"Enabled";
    }

    NotificationType notificationType = (NotificationType)[[NSUserDefaults standardUserDefaults] integerForKey:@"NotificationType"];
    [self.notificationTypeButton selectItemWithTag:notificationType];

    KeyCombo combo;
    combo.code = [[NSUserDefaults standardUserDefaults] integerForKey:@"OpenMenuKeyCode"];
    combo.flags = [[NSUserDefaults standardUserDefaults] integerForKey:@"OpenMenuKeyFlags"];
    if (combo.code > -1) [self.keyRecorderControl setKeyCombo:combo];
    
    self.launchAtStartupButton.state = [LoginItems userLoginItems].currentAppLaunchesAtStartup ? NSOnState : NSOffState;
    
    self.hideDockIconButton.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"HideDockIcon"] ? NSOnState : NSOffState;
}

// No dealloc - PreferencesController lives forever!

- (void)showPreferences {
    // Transform process from background to foreground
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	SetFrontProcess(&psn);
    
	[self.window center];

    [self.window makeKeyAndOrderFront:self];

#if DEBUG
    [self.toolbar setSelectedItemIdentifier:@"accounts"];
    [self selectAccountsTab:nil];
    #ifdef ISOLATE_ACCOUNTS
    [self addAccount:nil];
    #endif
#else
    [self.window setLevel: NSTornOffMenuWindowLevel]; // a.k.a. "Always On Top"
#endif
}

- (void)resizeWindowForContentSize:(NSSize)size {
    static BOOL firstTime = YES;
	NSRect windowFrame = [NSWindow contentRectForFrameRect:[[self window] frame]
                                                 styleMask:[[self window] styleMask]];
	NSRect newWindowFrame = [NSWindow frameRectForContentRect:
                             NSMakeRect( NSMinX( windowFrame ), NSMaxY( windowFrame ) - size.height, size.width, size.height )
                                                    styleMask:[[self window] styleMask]];
	[[self window] setFrame:newWindowFrame display:YES animate:(!firstTime && [[self window] isVisible])];
    firstTime = NO;
}

- (IBAction)selectGeneralTab:(id)sender {
    [self.tabView selectTabViewItemWithIdentifier:@"general"];
    [self.generalView setHidden:YES];
    [self resizeWindowForContentSize:NSMakeSize(self.window.frame.size.width, 310)];
    [self performSelector:@selector(revealView:) withObject:self.generalView afterDelay:0.075];
}

- (IBAction)selectAccountsTab:(id)sender {
    [self.tabView selectTabViewItemWithIdentifier:@"accounts"];
    [self.accountsView setHidden:YES];
    [self resizeWindowForContentSize:NSMakeSize(self.window.frame.size.width, 400)];
    [self performSelector:@selector(revealView:) withObject:self.accountsView afterDelay:0.075];
}

- (void)revealView:(NSView *)view {
    [view setHidden:NO];
}

#pragma mark General

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo {
    [[NSUserDefaults standardUserDefaults] setInteger:newKeyCombo.code forKey:@"OpenMenuKeyCode"];
    [[NSUserDefaults standardUserDefaults] setInteger:newKeyCombo.flags forKey:@"OpenMenuKeyFlags"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FeedsHotKeysChanged" object:nil];
}

- (void)notificationTypeChanged:(id)sender {
    NotificationType notificationType = (NotificationType)self.notificationTypeButton.selectedTag;
    [[NSUserDefaults standardUserDefaults] setInteger:notificationType forKey:@"NotificationType"];
}

- (void)launchAtStartupChanged:(id)sender {
    [LoginItems userLoginItems].currentAppLaunchesAtStartup = (self.launchAtStartupButton.state == NSOnState);
}

- (void)hideDockIconChanged:(id)sender {
    BOOL hideDockIcon = (self.hideDockIconButton.state == NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:hideDockIcon forKey:@"HideDockIcon"];
}

#pragma mark Accounts

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [[Account allAccounts] count];
}

- (Account *)selectedAccount {
    return [Account allAccounts][self.tableView.selectedRow];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Account *account = [Account allAccounts][row];
    return @{@"iconPrefix": account.iconPrefix ?: @"",
             @"name": account.name ?: [[account class] shortAccountName],
             @"username": account.username ?: @"",
             @"domain": account.friendlyDomain ?: @""};
}

- (BOOL)tableView:(NSTableView *)tableView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return NO;
}

- (IBAction)addAccount:(id)sender {
    self.createAccountController = [[CreateAccountController alloc] initWithDelegate:self];
    DDLogInfo(@"Presenting CreateAccountController.");
    [NSApp beginSheet:self.createAccountController.window modalForWindow:self.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (void)createAccountController:(CreateAccountController *)controller_ didCompleteWithAccount:(Account *)account {
    
    [Account addAccount:account];
    [self.tableView reloadData];
    [self.tableView scrollRowToVisible:self.tableView.numberOfRows-1];
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:self.tableView.numberOfRows-1] byExtendingSelection:NO];
    
    [NSApp endSheet:self.createAccountController.window];
    self.createAccountController = nil;
}

- (void)createAccountControllerDidCancel:(CreateAccountController *)controller_ {
    [NSApp endSheet:self.createAccountController.window];
    self.createAccountController = nil;
}

- (void)updateDetailView {
    [self.removeButton setEnabled:self.tableView.selectedRow >= 0];
    [self updateFeedsPanel];
    [self updateOptionsPanel];
}

- (void)updateFeedsPanel {
    // cancel any pending account validation
    [[Account allAccounts] makeObjectsPerformSelector:@selector(cancelValidation)];
    [[Account allAccounts] makeObjectsPerformSelector:@selector(setDelegate:) withObject:nil];
    self.feedsTableView.dataSource = nil;
    [self.findFeedsWarning setHidden:YES];
    
    if (self.tableView.selectedRow >= 0) {
        // refresh the available feeds by reauthenticating to this account
        self.selectedAccount.delegate = self;
        
        self.findFeedsProgress.hidden = NO;
        self.findFeedsLabel.hidden = NO;
        [self.findFeedsLabel setStringValue:@"Finding feeds…"];
        [self.findFeedsProgress startAnimation:nil];
        self.oldFeeds = self.selectedAccount.feeds; // preserve old feeds because existing FeedItems in our main menu might point to them (weak links)
        
        DDLogInfo(@"Validating account %@", self.selectedAccount);
        [self.selectedAccount validateWithPassword:[self.selectedAccount findPassword]];
    }
    else {
        [self.findFeedsProgress stopAnimation:nil];
        self.findFeedsProgress.hidden = YES;
        self.findFeedsLabel.hidden = YES;
    }
}

- (IBAction)removeAccount:(id)sender {
    Account *account = [Account allAccounts][self.tableView.selectedRow];
    [Account removeAccount:account];
    NSUInteger previouslySelectedRow = self.tableView.selectedRow;
    [self.tableView reloadData];
    
    // technically, removing an account from the middle of the list won't call tableViewSelectionDidChange: because, technically, the selected index is the same.
    // so we can't rely on that getting called every time.
    if (self.tableView.selectedRow == previouslySelectedRow)
        [self updateDetailView];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self updateDetailView];
}

- (void)account:(Account *)account validationDidContinueWithMessage:(NSString *)message {
    DDLogInfo(@"Validation continuing for account %@: %@", self.selectedAccount, message);
    [self.findFeedsLabel setStringValue:message];
}

- (void)account:(Account *)account validationDidRequireUsernameAndPasswordWithMessage:(NSString *)message {
    [self account:account validationDidFailWithMessage:message field:AccountFailingFieldUnknown];
}

- (void)account:(Account *)account validationDidFailWithMessage:(NSString *)message field:(AccountFailingField)field {

    DDLogError(@"Validation failed for account %@: %@", self.selectedAccount, message);
    
    [self.findFeedsProgress stopAnimation:nil];
    [self.findFeedsProgress setHidden:YES];
    
    [self.findFeedsWarning setHidden:NO];
    [self.findFeedsLabel setStringValue:message];
}

- (void)account:(Account *)account validationDidCompleteWithNewPassword:(NSString *)password {
    DDLogInfo(@"Validation completed for account %@.", self.selectedAccount);
    [self.findFeedsProgress stopAnimation:nil];
    [self.findFeedsProgress setHidden:YES];
    [self.findFeedsLabel setHidden:YES];
    
    if ([account.feeds isEqualToArray:self.oldFeeds]) {
        // if nothing has changed, keep our old feed objects to preserve non-retained references from any existing FeedItems.
        account.feeds = self.oldFeeds;
    }
    else {
        DDLogInfo(@"Available feeds changed! Saving accounts.");
        
        // copy over the disabled flag for accounts we already had
        for (Feed *feed in account.feeds) {
            NSUInteger index = [self.oldFeeds indexOfObject:feed];
            if (index != NSNotFound) {
                Feed *old = self.oldFeeds[index];
                feed.disabled = old.disabled;
            }
        }
        
        [Account saveAccounts];
    }
    
    self.feedsTableView.dataSource = account;
}

#pragma mark Options

- (void)updateOptionsPanel {
    if (self.tableView.selectedRow >= 0) {
        [self.accountNameLabel setEnabled:YES];
        [self.accountNameLabel setStringValue:self.selectedAccount.name ?: [[self.selectedAccount class] friendlyAccountName]];
        [self.refreshIntervalButton setEnabled:YES];
        [self.refreshIntervalButton selectItemWithTag:self.selectedAccount.refreshInterval / 60];
    }
    else {
        [self.accountNameLabel setEnabled:NO];
        [self.accountNameLabel setStringValue:@""];
        [self.refreshIntervalButton setEnabled:NO];
        [self.refreshIntervalButton selectItemAtIndex:0];
    }

    // update the default interval item title
//    int minutes = [self.selectedAccount.class defaultRefreshInterval] / 60;
//    if (minutes == 1)
//        [defaultRefreshIntervalItem setTitle:@"Default (every minute)"];
//    else
//        [defaultRefreshIntervalItem setTitle:[NSString stringWithFormat:@"Default (%i minutes)", minutes]];
}

- (void)accountNameChanged:(id)sender {
    NSString *name = self.accountNameLabel.stringValue;
    if (!name.length || [name isEqualToString:[[self.selectedAccount class] shortAccountName]])
        name = nil;
    self.selectedAccount.name = name;
    [self.tableView reloadData];
    [Account saveAccounts];
}

- (void)refreshIntervalChanged:(id)sender {
    NSTimeInterval interval = self.refreshIntervalButton.selectedTag * 60; // we store the interval in minutes in the "Tag" property
    self.selectedAccount.refreshInterval = interval;
    [Account saveAccounts];
}

- (void)menuWillOpen:(NSMenu *)menu {
    // you can only see the "Every 1 minute" option if you hold Option before clicking the refresh interval popup
    BOOL optionHeldDown = ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0;
    [self.oneMinuteRefreshIntervalItem setHidden:!optionHeldDown];
}

@end
