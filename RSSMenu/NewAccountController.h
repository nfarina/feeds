#import "Account.h"

@protocol NewAccountControllerDelegate;

@interface NewAccountController : NSWindowController <NSTextFieldDelegate, AccountDelegate> {
    id<NewAccountControllerDelegate> delegate;
    Account *newAccount;
    
    IBOutlet NSPopUpButton *accountTypeButton;
    IBOutlet NSTextField *domainField, *usernameField, *passwordField, *messageField;
    IBOutlet NSProgressIndicator *progress;
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