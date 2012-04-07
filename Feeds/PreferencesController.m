#import "PreferencesController.h"
#import "LoginItems.h"

@implementation PreferencesController
@synthesize oldFeeds;

- (id)initPreferencesController {
    if ([super initWithWindowNibName:@"PreferencesController"]) {
        // Initialization code here.
    }
    return self;
}

- (void)awakeFromNib {
    [toolbar setSelectedItemIdentifier:@"general"];
    [self selectGeneralTab:nil];
    [self tableViewSelectionDidChange:nil];
    
//    NSTimeInterval refreshInterval = [[NSUserDefaults standardUserDefaults] integerForKey:@"RefreshInterval"] ?: DEFAULT_REFRESH_INTERVAL;
//    [refreshIntervalButton selectItemWithTag:refreshInterval];
    
    BOOL disableNotifications = [[NSUserDefaults standardUserDefaults] boolForKey:@"DisableNotifications"];
    showNotificationsButton.state = (disableNotifications ? NSOffState : NSOnState);

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
    #ifdef ISOLATE_ACCOUNT
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

//- (void)refreshIntervalChanged:(id)sender {
//    NSTimeInterval refreshInterval = refreshIntervalButton.selectedItem.tag; // cleverly the menuitem "tag" is the refresh interval
//    [[NSUserDefaults standardUserDefaults] setInteger:refreshInterval forKey:@"RefreshInterval"];
//    [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshIntervalChanged" object:nil];
//}

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo {
    [[NSUserDefaults standardUserDefaults] setInteger:newKeyCombo.code forKey:@"OpenMenuKeyCode"];
    [[NSUserDefaults standardUserDefaults] setInteger:newKeyCombo.flags forKey:@"OpenMenuKeyFlags"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FeedsHotKeysChanged" object:nil];
}

- (void)showNotificationsChanged:(id)sender {
    BOOL showNotifications = (showNotificationsButton.state == NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:!showNotifications forKey:@"DisableNotifications"];
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

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Account *account = [[Account allAccounts] objectAtIndex:row];
    return [NSDictionary dictionaryWithObjectsAndKeys:account.type, @"type", [[account class] shortAccountName], @"name", account.username, @"username", account.domain, @"domain", nil];
}

- (BOOL)tableView:(NSTableView *)tableView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return NO;
}

- (IBAction)addAccount:(id)sender {
    NewAccountController *controller = [[NewAccountController alloc] initWithDelegate:self];
    
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

- (IBAction)removeAccount:(id)sender {
    Account *account = [[Account allAccounts] objectAtIndex:[tableView selectedRow]];
    [Account removeAccount:account];
    [tableView reloadData];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [removeButton setEnabled:tableView.selectedRow >= 0];

    // cancel any pending account validation
    [[Account allAccounts] makeObjectsPerformSelector:@selector(cancelValidation)];
    [[Account allAccounts] makeObjectsPerformSelector:@selector(setDelegate:) withObject:nil];
    feedsTableView.dataSource = nil;
    [findFeedsWarning setHidden:YES];

    if (tableView.selectedRow >= 0) {
        // refresh the available feeds by reauthenticating to this account
        Account *selectedAccount = [[Account allAccounts] objectAtIndex:tableView.selectedRow];
        selectedAccount.delegate = self;
        
        findFeedsProgress.hidden = NO;
        findFeedsLabel.hidden = NO;
        [findFeedsLabel setStringValue:@"Finding feeds…"];
        [findFeedsProgress startAnimation:nil];
        self.oldFeeds = selectedAccount.feeds; // preserve old feeds because existing FeedItems in our main menu might point to them (weak links)
        
        [selectedAccount validateWithPassword:[selectedAccount findPassword]];
    }
    else {
        [findFeedsProgress stopAnimation:nil];
        findFeedsProgress.hidden = YES;
        findFeedsLabel.hidden = YES;
    }
}

- (void)account:(Account *)account validationDidContinueWithMessage:(NSString *)message {
    [findFeedsLabel setStringValue:message];
}

- (void)account:(Account *)account validationDidFailWithMessage:(NSString *)message field:(AccountFailingField)field {

    [findFeedsProgress stopAnimation:nil];
    [findFeedsProgress setHidden:YES];
    
    [findFeedsWarning setHidden:NO];
    [findFeedsLabel setStringValue:message];
}

- (void)account:(Account *)account validationDidCompleteWithPassword:(NSString *)password {
    [findFeedsProgress stopAnimation:nil];
    [findFeedsProgress setHidden:YES];
    [findFeedsLabel setHidden:YES];
    
    if ([account.feeds isEqualToArray:oldFeeds]) {
        // if nothing has changed, keep our old feed objects to preserve non-retained references from any existing FeedItems.
        account.feeds = oldFeeds;
    }
    else {
        NSLog(@"Available feeds changed! Saving accounts.");
        
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

@end
