#import "PreferencesController.h"

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
//    [self selectAccountsTab:nil];
//    [self addAccount:nil];
#else
    [self.window setLevel: NSTornOffMenuWindowLevel]; // a.k.a. "Always On Top"
#endif
}

- (IBAction)selectGeneralTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"general"];
}

- (IBAction)selectAccountsTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"accounts"];
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
