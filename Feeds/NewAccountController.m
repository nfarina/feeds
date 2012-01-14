#import "NewAccountController.h"
#import "BasecampAccount.h"
#import "HighriseAccount.h"
#import "DribbbleAccount.h"
#import "GithubAccount.h"
#import "UserVoiceAccount.h"
#import "TrelloAccount.h"

@interface NewAccountController ()
@property (nonatomic, retain) Account *account;
@property (nonatomic, copy) NSString *password;
@end

@implementation NewAccountController
@synthesize account, password;

- (id)initWithDelegate:(id<NewAccountControllerDelegate>)theDelegate {
    delegate = theDelegate;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openURL:) name:@"GetURL" object:nil];
    return [super initWithWindowNibName:@"NewAccountController"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.account = nil;
    self.password = nil;
    [super dealloc];
}

- (void)awakeFromNib {
    for (Class cls in [Account registeredClasses]) {
        NSString *name = [cls friendlyAccountName];
        [accountTypeButton addItemWithTitle:name];
    }
    [progress setHidden:YES];
    [messageField setHidden:YES];
    [usernameField becomeFirstResponder];
    [self accountTypeChanged:nil];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [domainField becomeFirstResponder];
}

- (Class)selectedAccountClass {
    return [[Account registeredClasses] objectAtIndex:[accountTypeButton indexOfSelectedItem]];
}

- (NSString *)selectedAccountName {
    return [self.selectedAccountClass friendlyAccountName];
}

- (void)accountTypeChanged:(id)sender {
    Class accountClass = [self selectedAccountClass];
    [domainLabel setHidden:![accountClass requiresDomain]];
    [domainPrefix setHidden:![accountClass requiresDomain]];
    [domainSuffix setStringValue:[accountClass domainSuffix]];
    [domainField setHidden:![accountClass requiresDomain]];
    [usernameLabel setHidden:![accountClass requiresUsername]];
    [usernameField setHidden:![accountClass requiresUsername]];
    [passwordLabel setHidden:![accountClass requiresPassword]];
    [passwordField setHidden:![accountClass requiresPassword]];
    
    if ([accountClass requiresDomain])
        [domainField becomeFirstResponder];
    else if ([accountClass requiresUsername])
        [usernameField becomeFirstResponder];
    else if ([accountClass requiresPassword])
        [passwordField becomeFirstResponder];
    
    [self controlTextDidChange:nil];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    Class accountClass = [self selectedAccountClass];
    BOOL canContinue = YES;
    
    if ([accountClass requiresDomain] && [[domainField stringValue] length] == 0) canContinue = NO;
    if ([accountClass requiresUsername] && [[usernameField stringValue] length] == 0) canContinue = NO;
    if ([accountClass requiresPassword] && [[passwordField stringValue] length] == 0) canContinue = NO;

    [OKButton setEnabled:canContinue];
}

- (void)OKPressed:(id)sender {
    
    self.account = [[[[self selectedAccountClass] alloc] init] autorelease];
    account.delegate = self;

    Class accountClass = [self selectedAccountClass];

    if ([accountClass requiredAuthURL]) {
        [[NSWorkspace sharedWorkspace] openURL:[accountClass requiredAuthURL]];
        [messageField setStringValue:[NSString stringWithFormat:@"Authenticating with %@…",self.selectedAccountName]];
    }
    else {
        account.domain = [domainField stringValue];
        account.username = [usernameField stringValue];
        self.password = [passwordField stringValue];
        [account validateWithPassword:password];
        [messageField setStringValue:@"Validating account…"];
    }
    
    [OKButton setEnabled:NO];
    [progress setHidden:NO];
    [progress startAnimation:nil];
    [messageField setHidden:NO];
    [warningIcon setHidden:YES];
    [domainInvalid setHidden:YES];
    [usernameInvalid setHidden:YES];
    [passwordInvalid setHidden:YES];
}

- (void)openURL:(NSNotification *)notification {
    NSURL *URL = [notification.userInfo objectForKey:@"URL"];
    [account authWasFinishedWithURL:URL];
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

- (void)account:(Account *)theAccount validationDidCompleteWithPassword:(NSString *)changedPassword {

    if (changedPassword)
        self.password = changedPassword;
    
    [account savePassword:password];
    
    [progress stopAnimation:nil];
    [progress setHidden:YES];
    [messageField setHidden:YES];
    [self.window orderOut:self];
    [delegate newAccountController:self didCompleteWithAccount:account];
}

- (void)cancelPressed:(id)sender {
    [self.window orderOut:self];
    [delegate newAccountControllerDidCancel:self];
}

@end
