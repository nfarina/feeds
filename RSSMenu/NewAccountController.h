#import "Account.h"

@protocol NewAccountControllerDelegate;

@interface NewAccountController : NSWindowController <NSTextFieldDelegate, AccountDelegate> {
    id<NewAccountControllerDelegate> delegate;
    Account *account;
    NSString *password;
    
    IBOutlet NSPopUpButton *accountTypeButton;
    IBOutlet NSTextField *domainField, *usernameField, *passwordField, *messageField;
    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSImageView *warningIcon, *domainInvalid, *usernameInvalid, *passwordInvalid;
    IBOutlet NSButton *OKButton;
}

- (id)initWithDelegate:(id<NewAccountControllerDelegate>)delegate;

- (IBAction)accountTypeChanged:(id)sender;

- (IBAction)cancelPressed:(id)sender;
- (IBAction)OKPressed:(id)sender;

@end


@protocol NewAccountControllerDelegate <NSObject>

- (void)newAccountControllerDidCancel:(NewAccountController *)controller;
- (void)newAccountController:(NewAccountController *)controller didCompleteWithAccount:(Account *)account;

@end