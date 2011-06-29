#import "NewAccountController.h"
#import "BasecampAccount.h"

static NSArray *accountTypes = nil;

@interface NewAccountController ()
@property (nonatomic, retain) Account *newAccount;
@end

@implementation NewAccountController
@synthesize newAccount;

+ (void)initialize {
    if (self == [NewAccountController class]) {
        accountTypes = [[NSArray alloc] initWithObjects:
                        [NSDictionary dictionaryWithObjectsAndKeys:@"Basecamp",@"name",[BasecampAccount class],@"class",nil],
                        nil];
    }
}

- (id)initWithDelegate:(id<NewAccountControllerDelegate>)theDelegate {
    delegate = theDelegate;
    return [super initWithWindowNibName:@"NewAccountController"];
}

- (void)dealloc {
    self.newAccount = nil;
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
    [usernameField becomeFirstResponder];
}

- (void)accountTypeChanged:(id)sender {
}

- (void)controlTextDidChange:(NSNotification *)notification {
    BOOL canContinue = [[usernameField stringValue] length] && [[passwordField stringValue] length];
    [OKButton setEnabled:canContinue];
}

- (void)OKPressed:(id)sender {
    NSDictionary *accountType = [accountTypes objectAtIndex:[accountTypeButton indexOfSelectedItem]];
    Class class = [accountType objectForKey:@"class"];
    
    self.newAccount = [[[class alloc] init] autorelease];
    newAccount.username = [usernameField stringValue];
    newAccount.password = [passwordField stringValue];
}

- (void)cancelPressed:(id)sender {
    [self.window orderOut:self];
    [delegate newAccountControllerDidCancel:self];
}

@end
