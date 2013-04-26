#import "Account.h"

@protocol CreateAccountControllerDelegate;

@interface CreateAccountController : NSWindowController

- (id)initWithDelegate:(id<CreateAccountControllerDelegate>)delegate;

@end


@protocol CreateAccountControllerDelegate <NSObject>

- (void)createAccountControllerDidCancel:(CreateAccountController *)controller;
- (void)createAccountController:(CreateAccountController *)controller didCompleteWithAccount:(Account *)account;

@end
