
@interface PreferencesController : NSWindowController <NSToolbarDelegate, NSTabViewDelegate> {
    IBOutlet NSToolbar *toolbar;
    IBOutlet NSTabView *tabView;
}

- (id)initPreferencesController;
- (void)showPreferences;

- (IBAction)selectGeneralTab:(id)sender;
- (IBAction)selectAccountsTab:(id)sender;

@end
