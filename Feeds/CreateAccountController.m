#import "CreateAccountController.h"
#import "BasecampAccount.h"
#import "HighriseAccount.h"
#import "DribbbleAccount.h"
#import "GithubAccount.h"
#import "UserVoiceAccount.h"
#import "TrelloAccount.h"

@interface CreateAccountController () <NSTextFieldDelegate, AccountDelegate>
@property (nonatomic, strong) IBOutlet NSPopUpButton *accountTypeButton;
@property (nonatomic, strong) IBOutlet NSTextField *domainLabel, *domainPrefix, *domainSuffix, *usernameLabel, *passwordLabel;
@property (nonatomic, strong) IBOutlet NSTextField *domainField, *usernameField, *passwordField, *messageField;
@property (nonatomic, strong) IBOutlet NSProgressIndicator *progress;
@property (nonatomic, strong) IBOutlet NSImageView *warningIcon, *domainInvalid, *usernameInvalid, *passwordInvalid;
@property (nonatomic, strong) IBOutlet NSButton *OKButton;
@property (nonatomic, unsafe_unretained) id<CreateAccountControllerDelegate> delegate;
@property (nonatomic, strong) Account *account;
@property (nonatomic, copy) NSString *password;
@end

@implementation CreateAccountController

- (id)initWithDelegate:(id<CreateAccountControllerDelegate>)delegate {
    self.delegate = delegate;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openURL:) name:@"GetURL" object:nil];
    return [super initWithWindowNibName:@"CreateAccountController"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib {
    for (Class cls in [Account registeredClasses]) {
        NSString *name = [cls friendlyAccountName];
        [self.accountTypeButton addItemWithTitle:name];
        
        #ifdef ISOLATE_ACCOUNTS
        if ([NSStringFromClass(cls) isEqualToString:[ISOLATE_ACCOUNTS firstObject]]) [accountTypeButton selectItemWithTitle:name];
        #endif
    }
    [self.progress setHidden:YES];
    [self.messageField setHidden:YES];
    [self.usernameField becomeFirstResponder];
    
    [self accountTypeChanged:nil];
}

- (Class)selectedAccountClass {
    return [Account registeredClasses][[self.accountTypeButton indexOfSelectedItem]];
}

- (NSString *)selectedAccountName {
    return [self.selectedAccountClass friendlyAccountName];
}

- (void)accountTypeChanged:(id)sender {
    Class accountClass = [self selectedAccountClass];
    DDLogInfo(@"Selected account type %@", accountClass);
    [self.domainLabel setHidden:![accountClass requiresDomain]];
    [self.domainLabel setStringValue:[accountClass domainLabel]];
    [self.domainPrefix setHidden:![accountClass requiresDomain]];
    [self.domainPrefix setStringValue:[accountClass domainPrefix]];
    [self.domainSuffix setHidden:![accountClass requiresDomain]];
    [self.domainSuffix setStringValue:[accountClass domainSuffix]];
    [self.domainField setHidden:![accountClass requiresDomain]];
    [self.domainField.cell setPlaceholderString:[accountClass domainPlaceholder]];
    [self.usernameLabel setHidden:![accountClass requiresUsername]];
    [self.usernameLabel setStringValue:[accountClass usernameLabel]];
    [self.usernameField setHidden:![accountClass requiresUsername]];
    [self.passwordLabel setHidden:![accountClass requiresPassword]];
    [self.passwordLabel setStringValue:[accountClass passwordLabel]];
    [self.passwordField setHidden:![accountClass requiresPassword]];
    
    // layout the domain prefix/suffix left-to-right
    [self.domainPrefix sizeToFit];
    [self.domainSuffix sizeToFit];
    
    CGFloat prefixWidth = self.domainPrefix.stringValue.length ? self.domainPrefix.frame.size.width : 0;
    CGFloat suffixWidth = self.domainSuffix.stringValue.length ? self.domainSuffix.frame.size.width : 0;
    CGFloat domainX = self.accountTypeButton.frame.origin.x;
    CGFloat totalWidth = self.accountTypeButton.frame.size.width;
    
    if (prefixWidth == 0) domainX += 2; // nudge everything to the left if no prefix
    if (suffixWidth == 0) suffixWidth = 3; // make the box a bit smaller if no suffix
    
    // align the suffix to the right
    NSRect domainSuffixFrame = self.domainSuffix.frame;
    domainSuffixFrame.origin.x = domainX + totalWidth - suffixWidth;
    self.domainSuffix.frame = domainSuffixFrame;

    // put the domain field between the prefix and suffix
    NSRect domainFieldFrame = self.domainField.frame;
    domainFieldFrame.origin.x = domainX + prefixWidth;
    domainFieldFrame.size.width = totalWidth - prefixWidth - suffixWidth - 2;
    self.domainField.frame = domainFieldFrame;

    if ([accountClass requiresDomain])
        [self.domainField becomeFirstResponder];
    else if ([accountClass requiresUsername])
        [self.usernameField becomeFirstResponder];
    else if ([accountClass requiresPassword])
        [self.passwordField becomeFirstResponder];
    
    [self controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:nil]];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    Class accountClass = [self selectedAccountClass];
    BOOL canContinue = YES;
    
    if ([accountClass requiresDomain] && [[self.domainField stringValue] length] == 0) canContinue = NO;
    if ([accountClass requiresUsername] && [[self.usernameField stringValue] length] == 0) canContinue = NO;
    if ([accountClass requiresPassword] && [[self.passwordField stringValue] length] == 0) canContinue = NO;

    [self.OKButton setEnabled:canContinue];
}

- (void)OKPressed:(id)sender {
    
    [self.OKButton setEnabled:NO];
    [self.progress setHidden:NO];
    [self.progress startAnimation:nil];
    [self.messageField setHidden:NO];
    [self.warningIcon setHidden:YES];
    [self.domainInvalid setHidden:YES];
    [self.usernameInvalid setHidden:YES];
    [self.passwordInvalid setHidden:YES];

    self.account = [[[self selectedAccountClass] alloc] init];
    self.account.delegate = self;
    Class accountClass = [self selectedAccountClass];

    // make sure to call the [account] methods as the last lines of this function, as they could immediately call our delegate methods thereafter
    
    if ([accountClass requiresAuth]) {
        [self.messageField setStringValue:[NSString stringWithFormat:@"Authenticating with %@…",self.selectedAccountName]];
        [self.account beginAuth];
    }
    else {
        self.account.domain = [self.domainField stringValue];
        self.account.username = [self.usernameField stringValue];
        self.password = [self.passwordField stringValue];
        DDLogInfo(@"Validating account %@", self.account);
        [self.messageField setStringValue:@"Validating account…"];
        [self.account validateWithPassword:self.password];
    }
}

- (void)openURL:(NSNotification *)notification {
    NSURL *URL = (notification.userInfo)[@"URL"];
    [self.account authWasFinishedWithURL:URL];
}

- (void)account:(Account *)theAccount validationDidContinueWithMessage:(NSString *)message {
    DDLogInfo(@"Validation continuing for account %@: %@", self.account, message);
    [self.messageField setStringValue:message];
}

- (void)account:(Account *)theAccount validationDidRequireUsernameAndPasswordWithMessage:(NSString *)message {
    [self.usernameField setHidden:NO];
    [self.usernameLabel setHidden:NO];
    [self.passwordField setHidden:NO];
    [self.passwordLabel setHidden:NO];
    [self account:self.account validationDidFailWithMessage:message field:AccountFailingFieldUnknown];
    [self.usernameField becomeFirstResponder];
}

- (void)account:(Account *)theAccount validationDidFailWithMessage:(NSString *)message field:(AccountFailingField)field {
    
    DDLogError(@"Validation failed for account %@: %@", self.account, message);

    [self.progress stopAnimation:nil];
    [self.progress setHidden:YES];
    
    [self.warningIcon setHidden:NO];
    [self.messageField setStringValue:message];

    [self.OKButton setEnabled:YES];

    if (field == AccountFailingFieldDomain)
        [self.domainInvalid setHidden:NO];
    else if (field == AccountFailingFieldUsername)
        [self.usernameInvalid setHidden:NO];
    else if (field == AccountFailingFieldPassword)
        [self.passwordInvalid setHidden:NO];
}

- (void)account:(Account *)theAccount validationDidCompleteWithNewPassword:(NSString *)changedPassword {

    DDLogInfo(@"Validation completed for account %@.", self.account);

    if (changedPassword)
        self.password = changedPassword;
    
    [self.account savePassword:self.password];
    
    [self.progress stopAnimation:nil];
    [self.progress setHidden:YES];
    [self.messageField setHidden:YES];
    [self.window orderOut:self];
    [self.delegate createAccountController:self didCompleteWithAccount:self.account];
}

- (void)cancelPressed:(id)sender {
    [self.window orderOut:self];
    [self.delegate createAccountControllerDidCancel:self];
}

@end
