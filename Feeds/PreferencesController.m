#import "PreferencesController.h"
#import "LoginItems.h"

@implementation PreferencesController

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
    
    NSTimeInterval refreshInterval = [[NSUserDefaults standardUserDefaults] integerForKey:@"RefreshInterval"] ?: DEFAULT_REFRESH_INTERVAL;
    [refreshIntervalButton selectItemWithTag:refreshInterval];
    
    BOOL disableNotifications = [[NSUserDefaults standardUserDefaults] boolForKey:@"DisableNotifications"];
    showNotificationsButton.state = (disableNotifications ? NSOffState : NSOnState);

    KeyCombo combo;
    combo.code = [[NSUserDefaults standardUserDefaults] integerForKey:@"OpenMenuKeyCode"];
    combo.flags = [[NSUserDefaults standardUserDefaults] integerForKey:@"OpenMenuKeyFlags"];
    if (combo.code > -1) [keyRecorderControl setKeyCombo:combo];
    
    launchAtStartupButton.state = [LoginItems userLoginItems].currentAppLaunchesAtStartup ? NSOnState : NSOffState;
}

- (void)dealloc {
    [toolbar release];
    [tabView release];
    [super dealloc];
}

- (void)showPreferences {
    // Transform process from background to foreground
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	SetFrontProcess(&psn);
    
	[self.window center];

    [self.window makeKeyAndOrderFront:self];

#if DEBUG
//    [toolbar setSelectedItemIdentifier:@"accounts"];
//    [self selectAccountsTab:nil];
//    [self addAccount:nil];
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
    [self resizeWindowForContentSize:NSMakeSize(self.window.frame.size.width, 240)];
    [self performSelector:@selector(revealView:) withObject:generalView afterDelay:0.075];
}

- (IBAction)selectAccountsTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"accounts"];
    [accountsView setHidden:YES];
    [self resizeWindowForContentSize:NSMakeSize(self.window.frame.size.width, 360)];
    [self performSelector:@selector(revealView:) withObject:accountsView afterDelay:0.075];
}

- (void)revealView:(NSView *)view {
    [view setHidden:NO];
}

#pragma mark General

- (void)refreshIntervalChanged:(id)sender {
    NSTimeInterval refreshInterval = refreshIntervalButton.selectedItem.tag; // cleverly the menuitem "tag" is the refresh interval
    [[NSUserDefaults standardUserDefaults] setInteger:refreshInterval forKey:@"RefreshInterval"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshIntervalChanged" object:nil];
}

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

#pragma mark Accounts

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [[Account allAccounts] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Account *account = [[Account allAccounts] objectAtIndex:row];
    return [NSDictionary dictionaryWithObjectsAndKeys:account.type, @"type", account.username, @"username", nil];
}

- (IBAction)addAccount:(id)sender {
    NewAccountController *controller = [[NewAccountController alloc] initWithDelegate:self];
    
    [NSApp beginSheet:controller.window modalForWindow:self.window modalDelegate:nil didEndSelector:NULL contextInfo:controller];
}

- (void)newAccountController:(NewAccountController *)controller didCompleteWithAccount:(Account *)account {
    
    [Account addAccount:account];
    [tableView reloadData];
    
    [NSApp endSheet:controller.window];
    [controller release];
}

- (void)newAccountControllerDidCancel:(NewAccountController *)controller {
    [NSApp endSheet:controller.window];
    [controller release];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [removeButton setEnabled:[tableView selectedRow] >= 0];
}

- (IBAction)removeAccount:(id)sender {
    Account *account = [[Account allAccounts] objectAtIndex:[tableView selectedRow]];
    [Account removeAccount:account];
    [tableView reloadData];
}

@end
