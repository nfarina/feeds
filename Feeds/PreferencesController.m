#import "PreferencesController.h"
#import "LoginItems.h"

@implementation PreferencesController
@synthesize oldFeeds;

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
    [toolbar setSelectedItemIdentifier:@"general"];
    [self selectGeneralTab:nil];
    [self tableViewSelectionDidChange:nil];
    
    // if we don't have Notification Center available (pre-mountain-lion) then we can't select it
    if (!HAS_NOTIFICATION_CENTER) {
        // hide the fact that Growl exists (you don't have a choice now)
        [notificationTypeButton removeItemAtIndex:0];
        notificationTypeGrowlItem.title = @"Enabled";
    }

    NotificationType notificationType = (NotificationType)[[NSUserDefaults standardUserDefaults] integerForKey:@"NotificationType"];
    [notificationTypeButton selectItemWithTag:notificationType];

    KeyCombo combo;
    combo.code = [[NSUserDefaults standardUserDefaults] integerForKey:@"OpenMenuKeyCode"];
    combo.flags = [[NSUserDefaults standardUserDefaults] integerForKey:@"OpenMenuKeyFlags"];
    if (combo.code > -1) [keyRecorderControl setKeyCombo:combo];
    
    launchAtStartupButton.state = [LoginItems userLoginItems].currentAppLaunchesAtStartup ? NSOnState : NSOffState;
    
    hideDockIconButton.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"HideDockIcon"] ? NSOnState : NSOffState;
}

// No dealloc - PreferencesController lives forever!

- (void)showPreferences {
    // Transform process from background to foreground
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	SetFrontProcess(&psn);
    
	[self.window center];

    [self.window makeKeyAndOrderFront:self];

#if DEBUG
    [toolbar setSelectedItemIdentifier:@"accounts"];
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
    [tabView selectTabViewItemWithIdentifier:@"general"];
    [generalView setHidden:YES];
    [self resizeWindowForContentSize:NSMakeSize(self.window.frame.size.width, 310)];
    [self performSelector:@selector(revealView:) withObject:generalView afterDelay:0.075];
}

- (IBAction)selectAccountsTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"accounts"];
    [accountsView setHidden:YES];
    [self resizeWindowForContentSize:NSMakeSize(self.window.frame.size.width, 400)];
    [self performSelector:@selector(revealView:) withObject:accountsView afterDelay:0.075];
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
    NotificationType notificationType = (NotificationType)notificationTypeButton.selectedTag;
    [[NSUserDefaults standardUserDefaults] setInteger:notificationType forKey:@"NotificationType"];
}

- (void)launchAtStartupChanged:(id)sender {
    [LoginItems userLoginItems].currentAppLaunchesAtStartup = (launchAtStartupButton.state == NSOnState);
}

- (void)hideDockIconChanged:(id)sender {
    BOOL hideDockIcon = (hideDockIconButton.state == NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:hideDockIcon forKey:@"HideDockIcon"];
}

#pragma mark Accounts

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [[Account allAccounts] count];
}

- (Account *)selectedAccount {
    return [[Account allAccounts] objectAtIndex:tableView.selectedRow];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Account *account = [[Account allAccounts] objectAtIndex:row];
    return [NSDictionary dictionaryWithObjectsAndKeys:account.iconPrefix, @"iconPrefix", account.name ?: [[account class] shortAccountName], @"name", account.username, @"username", account.friendlyDomain, @"domain", nil];
}

- (BOOL)tableView:(NSTableView *)tableView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return NO;
}

- (IBAction)addAccount:(id)sender {
    NewAccountController *controller = [[NewAccountController alloc] initWithDelegate:self];
    DDLogInfo(@"Presenting NewAccountController.");
    [NSApp beginSheet:controller.window modalForWindow:self.window modalDelegate:nil didEndSelector:NULL contextInfo:controller];
}

- (void)newAccountController:(NewAccountController *)controller didCompleteWithAccount:(Account *)account {
    
    [Account addAccount:account];
    [tableView reloadData];
    [tableView scrollRowToVisible:tableView.numberOfRows-1];
    [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:tableView.numberOfRows-1] byExtendingSelection:NO];
    
    [NSApp endSheet:controller.window];
    [controller release];
}

- (void)newAccountControllerDidCancel:(NewAccountController *)controller {
    [NSApp endSheet:controller.window];
    [controller release];
}

- (void)updateDetailView {
    [removeButton setEnabled:tableView.selectedRow >= 0];
    [self updateFeedsPanel];
    [self updateOptionsPanel];
}

- (void)updateFeedsPanel {
    // cancel any pending account validation
    [[Account allAccounts] makeObjectsPerformSelector:@selector(cancelValidation)];
    [[Account allAccounts] makeObjectsPerformSelector:@selector(setDelegate:) withObject:nil];
    feedsTableView.dataSource = nil;
    [findFeedsWarning setHidden:YES];
    
    if (tableView.selectedRow >= 0) {
        // refresh the available feeds by reauthenticating to this account
        self.selectedAccount.delegate = self;
        
        findFeedsProgress.hidden = NO;
        findFeedsLabel.hidden = NO;
        [findFeedsLabel setStringValue:@"Finding feeds…"];
        [findFeedsProgress startAnimation:nil];
        self.oldFeeds = self.selectedAccount.feeds; // preserve old feeds because existing FeedItems in our main menu might point to them (weak links)
        
        DDLogInfo(@"Validating account %@", self.selectedAccount);
        [self.selectedAccount validateWithPassword:[self.selectedAccount findPassword]];
    }
    else {
        [findFeedsProgress stopAnimation:nil];
        findFeedsProgress.hidden = YES;
        findFeedsLabel.hidden = YES;
    }
}

- (IBAction)removeAccount:(id)sender {
    Account *account = [[Account allAccounts] objectAtIndex:[tableView selectedRow]];
    [Account removeAccount:account];
    NSUInteger previouslySelectedRow = tableView.selectedRow;
    [tableView reloadData];
    
    // technically, removing an account from the middle of the list won't call tableViewSelectionDidChange: because, technically, the selected index is the same.
    // so we can't rely on that getting called every time.
    if (tableView.selectedRow == previouslySelectedRow)
        [self updateDetailView];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self updateDetailView];
}

- (void)account:(Account *)account validationDidContinueWithMessage:(NSString *)message {
    DDLogInfo(@"Validation continuing for account %@: %@", self.selectedAccount, message);
    [findFeedsLabel setStringValue:message];
}

- (void)account:(Account *)account validationDidRequireUsernameAndPasswordWithMessage:(NSString *)message {
    [self account:account validationDidFailWithMessage:message field:AccountFailingFieldUnknown];
}

- (void)account:(Account *)account validationDidFailWithMessage:(NSString *)message field:(AccountFailingField)field {

    DDLogError(@"Validation failed for account %@: %@", self.selectedAccount, message);
    
    [findFeedsProgress stopAnimation:nil];
    [findFeedsProgress setHidden:YES];
    
    [findFeedsWarning setHidden:NO];
    [findFeedsLabel setStringValue:message];
}

- (void)account:(Account *)account validationDidCompleteWithNewPassword:(NSString *)password {
    DDLogInfo(@"Validation completed for account %@.", self.selectedAccount);
    [findFeedsProgress stopAnimation:nil];
    [findFeedsProgress setHidden:YES];
    [findFeedsLabel setHidden:YES];
    
    if ([account.feeds isEqualToArray:oldFeeds]) {
        // if nothing has changed, keep our old feed objects to preserve non-retained references from any existing FeedItems.
        account.feeds = oldFeeds;
    }
    else {
        DDLogInfo(@"Available feeds changed! Saving accounts.");
        
        // copy over the disabled flag for accounts we already had
        for (Feed *feed in account.feeds) {
            NSUInteger index = [oldFeeds indexOfObject:feed];
            if (index != NSNotFound) {
                Feed *old = [oldFeeds objectAtIndex:index];
                feed.disabled = old.disabled;
            }
        }
        
        [Account saveAccounts];
    }
    
    feedsTableView.dataSource = account;
}

#pragma mark Options

- (void)updateOptionsPanel {
    [accountNameLabel setStringValue:self.selectedAccount.name ?: [[self.selectedAccount class] friendlyAccountName]];
    [refreshIntervalButton selectItemWithTag:self.selectedAccount.refreshInterval / 60];

    // update the default interval item title
//    int minutes = [self.selectedAccount.class defaultRefreshInterval] / 60;
//    if (minutes == 1)
//        [defaultRefreshIntervalItem setTitle:@"Default (every minute)"];
//    else
//        [defaultRefreshIntervalItem setTitle:[NSString stringWithFormat:@"Default (%i minutes)", minutes]];
}

- (void)accountNameChanged:(id)sender {
    NSString *name = accountNameLabel.stringValue;
    if (!name.length || [name isEqualToString:[[self.selectedAccount class] shortAccountName]])
        name = nil;
    self.selectedAccount.name = name;
    [tableView reloadData];
    [Account saveAccounts];
}

- (void)refreshIntervalChanged:(id)sender {
    NSTimeInterval interval = refreshIntervalButton.selectedTag * 60; // we store the interval in minutes in the "Tag" property
    self.selectedAccount.refreshInterval = interval;
    [Account saveAccounts];
}

- (void)menuWillOpen:(NSMenu *)menu {
    // you can only see the "Every 1 minute" option if you hold Option before clicking the refresh interval popup
    BOOL optionHeldDown = ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0;
    [oneMinuteRefreshIntervalItem setHidden:!optionHeldDown];
}

@end
