#import "PreferencesController.h"

@implementation PreferencesController

- (id)initPreferencesController {
    if ([super initWithWindowNibName:@"PreferencesController"]) {
        // Initialization code here.
    }
    return self;
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

//- (IBAction)closePreferences:(id)sender {
//	[window endEditingFor:[window firstResponder]];
//    [window performClose:sender];
//}

//- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
//    
//}
//
//- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
//    
//}
//
//- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
//    
//}
//
//- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
//    
//}

@end
