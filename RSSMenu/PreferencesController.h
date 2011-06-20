
@interface PreferencesController : NSWindowController <NSToolbarDelegate, NSTabViewDelegate> {
    IBOutlet NSToolbar *toolbar;
    IBOutlet NSTabView *tabView;
}

- (id)initPreferencesController;

- (void)showPreferences;

@end
