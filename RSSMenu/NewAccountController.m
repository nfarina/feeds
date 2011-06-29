#import "NewAccountController.h"
#import "BasecampAccount.h"

static NSArray *accountTypes = nil;

@implementation NewAccountController

+ (void)initialize {
    if (self == [NewAccountController class]) {
        accountTypes = [NSArray arrayWithObjects:
                        [NSDictionary dictionaryWithObjectsAndKeys:@"Basecamp",@"name",[BasecampAccount class],@"class",nil],
                        nil];
    }
}

- (id)initWithDelegate:(id<NewAccountControllerDelegate>)theDelegate {
    delegate = theDelegate;
    return [super initWithWindowNibName:@"NewAccountController"];
}

- (void)dealloc {
    [super dealloc];
}

- (void)awakeFromNib {
    for (NSDictionary *accountType in accountTypes) {
        NSString *name = [accountType objectForKey:@"name"];
        [accountTypeButton addItemWithTitle:name];
    }
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)accountTypeChanged:(id)sender {
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
