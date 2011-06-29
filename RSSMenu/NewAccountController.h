
@protocol NewAccountControllerDelegate;

@interface NewAccountController : NSWindowController {
    id<NewAccountControllerDelegate> delegate;
    
    IBOutlet NSPopUpButton *accountTypeButton;
    IBOutlet NSTextField *usernameButton;
    IBOutlet NSTextField *passwordButton;
    IBOutlet NSButton *OKButton;
}

- (id)initWithDelegate:(id<NewAccountControllerDelegate>)delegate;

- (IBAction)accountTypeChanged:(id)sender;

- (IBAction)cancelPressed:(id)sender;
- (IBAction)OKPressed:(id)sender;

@end


@protocol NewAccountControllerDelegate <NSObject>

- (void)newAccountControllerDidCancel:(NewAccountController *)controller;
- (void)newAccountControllerDidComplete:(NewAccountController *)controller;

@end