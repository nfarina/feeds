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
    [progress setHidden:YES];
    [messageField setHidden:YES];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [domainField becomeFirstResponder];
}

- (Class)selectedAccountClass {
    NSDictionary *accountType = [accountTypes objectAtIndex:[accountTypeButton indexOfSelectedItem]];
    return [accountType objectForKey:@"class"];
}

- (void)accountTypeChanged:(id)sender {
}

- (void)controlTextDidChange:(NSNotification *)notification {
    BOOL canContinue = [[domainField stringValue] length] && [[usernameField stringValue] length] && [[passwordField stringValue] length];
    [OKButton setEnabled:canContinue];
}

- (void)OKPressed:(id)sender {
    
    self.newAccount = [[[[self selectedAccountClass] alloc] init] autorelease];
    newAccount.delegate = self;
    newAccount.domain = [domainField stringValue];
    newAccount.username = [usernameField stringValue];
    newAccount.password = [passwordField stringValue];
    [newAccount validate];
    
    [progress setHidden:NO];
    [progress startAnimation:nil];
    [messageField setHidden:NO];
    [messageField setStringValue:@"Validating account…"];
}

- (void)accountValidationDidComplete:(Account *)account {

    [progress stopAnimation:nil];
    [progress setHidden:YES];
    [messageField setHidden:YES];
    [self.window orderOut:self];
    [delegate newAccountControllerDidComplete:self];
}

- (void)cancelPressed:(id)sender {
    [self.window orderOut:self];
    [delegate newAccountControllerDidCancel:self];
}

@end
