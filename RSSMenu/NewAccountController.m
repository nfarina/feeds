#import "NewAccountController.h"

@implementation NewAccountController

- (id)initWithDelegate:(id<NewAccountControllerDelegate>)theDelegate {
    delegate = theDelegate;
    return [super initWithWindowNibName:@"NewAccountController"];
}

- (void)dealloc {
    [super dealloc];
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)OKPressed:(id)sender {
    [self.window orderOut:self];
    [delegate newAccountControllerDidComplete:self];
}

- (void)cancelPressed:(id)sender {
    [self.window orderOut:self];
    [delegate newAccountControllerDidCancel:self];
}

@end
