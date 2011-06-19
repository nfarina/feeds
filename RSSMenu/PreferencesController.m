#import "PreferencesController.h"

@implementation PreferencesController

- (id)initPreferencesController {
    if ([super initWithWindowNibName:@"PreferencesController"]) {
        // Initialization code here.
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
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

@end
