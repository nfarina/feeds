#import "NewAccountController.h"
#import "BasecampAccount.h"

static NSArray *accountTypes = nil;

@interface NewAccountController ()
@property (nonatomic, retain) Account *account;
@end

@implementation NewAccountController
@synthesize account;

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
    self.account = nil;
    [super dealloc];
}

- (void)awakeFromNib {
    for (NSDictionary *accountType in accountTypes) {
        NSString *name = [accountType objectForKey:@"name"];
        [accountTypeButton addItemWithTitle:name];
    }
    [progress setHidden:YES];
    [messageField setHidden:YES];
    [usernameField becomeFirstResponder];
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
    
    self.account = [[[[self selectedAccountClass] alloc] init] autorelease];
    account.delegate = self;
    account.domain = [domainField stringValue];
    account.username = [usernameField stringValue];
    account.password = [passwordField stringValue];
    [account validate];
    
    [OKButton setEnabled:NO];
    [progress setHidden:NO];
    [progress startAnimation:nil];
    [messageField setHidden:NO];
    [messageField setStringValue:@"Validating account…"];
    [warningIcon setHidden:YES];
    [domainInvalid setHidden:YES];
    [usernameInvalid setHidden:YES];
    [passwordInvalid setHidden:YES];
}

- (void)account:(Account *)account validationDidContinueWithMessage:(NSString *)message {
    [messageField setStringValue:message];
}

- (void)account:(Account *)account validationDidFailWithMessage:(NSString *)message field:(AccountFailingField)field {
    
    [progress stopAnimation:nil];
    [progress setHidden:YES];
    
    [warningIcon setHidden:NO];
    [messageField setStringValue:message];

    [OKButton setEnabled:YES];

    if (field == AccountFailingFieldDomain)
        [domainInvalid setHidden:NO];
    else if (field == AccountFailingFieldUsername)
        [usernameInvalid setHidden:NO];
    else if (field == AccountFailingFieldPassword)
        [passwordInvalid setHidden:NO];
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
