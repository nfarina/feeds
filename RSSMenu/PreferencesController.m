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
}

- (void)dealloc {
    [toolbar release];
    [tabView release];
    [super dealloc];
}

- (void)loadWindow {
    [super loadWindow];
}

- (void)showPreferences {
    // Transform process from background to foreground
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	SetFrontProcess(&psn);
    
	[self.window center];
    
#if DEBUG
#else
    [self.window setLevel: NSTornOffMenuWindowLevel]; // a.k.a. "Always On Top"
#endif

    [self.window makeKeyAndOrderFront:self];
}

- (IBAction)selectGeneralTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"general"];
}

- (IBAction)selectAccountsTab:(id)sender {
    [tabView selectTabViewItemWithIdentifier:@"accounts"];
}

#pragma mark Accounts

- (IBAction)addAccount:(id)sender {
    NewAccountController *controller = [[NewAccountController alloc] initWithDelegate:self];
    
    [NSApp beginSheet:controller.window modalForWindow:self.window modalDelegate:nil didEndSelector:NULL contextInfo:controller];
}

- (void)newAccountControllerDidComplete:(NewAccountController *)controller {
    [NSApp endSheet:controller.window];
    [controller release];
}

- (void)newAccountControllerDidCancel:(NewAccountController *)controller {
    [NSApp endSheet:controller.window];
    [controller release];
}

- (IBAction)removeAccount:(id)sender {
    
}

@end
