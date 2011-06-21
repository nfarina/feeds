
@protocol NewAccountControllerDelegate;

@interface NewAccountController : NSWindowController {
    id<NewAccountControllerDelegate> delegate;
    IBOutlet NSButton *OKButton;
}

- (id)initWithDelegate:(id<NewAccountControllerDelegate>)delegate;

- (IBAction)cancelPressed:(id)sender;
- (IBAction)OKPressed:(id)sender;

@end


@protocol NewAccountControllerDelegate <NSObject>

- (void)newAccountControllerDidCancel:(NewAccountController *)controller;
- (void)newAccountControllerDidComplete:(NewAccountController *)controller;

@end