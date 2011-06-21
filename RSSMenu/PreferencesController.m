#import "PreferencesController.h"
#import "NewAccountController.h"

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
    [self.window setLevel: NSTornOffMenuWindowLevel];
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
    NewAccountController *controller = [[NewAccountController alloc] initNewAccountController];
    
    [NSApp beginSheet:controller.window modalForWindow:self.window modalDelegate:self didEndSelector:@selector(addAccountDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)addAccountDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    
}

- (IBAction)removeAccount:(id)sender {
    
}

@end
