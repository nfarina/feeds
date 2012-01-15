#import "Account.h"

NSString *kAccountsChangedNotification = @"AccountsChangedNotification";

static NSMutableArray *allAccounts = nil;

@interface Account ()
+ (Account *)accountWithDictionary:(NSDictionary *)dict;
@end

@implementation Account
@synthesize delegate, domain, username, request, feeds;

static NSMutableArray *registeredClasses = nil;

+ (NSArray *)registeredClasses { return registeredClasses; }
+ (void)registerClass:(Class)cls {
    if (!registeredClasses) registeredClasses = [NSMutableArray new];
    [registeredClasses addObject:cls];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data {
    if ([self class] == [Account class])
        for (Class accountClass in registeredClasses) {
            NSArray *items = [accountClass itemsForRequest:request data:data];
            if (items) return items;
        }
    return nil;
}

+ (NSString *)friendlyAccountName {
    return [NSStringFromClass(self) stringByReplacingOccurrencesOfString:@"Account" withString:@""];
}

+ (BOOL)requiresDomain { return NO; }
+ (BOOL)requiresUsername { return NO; }
+ (BOOL)requiresPassword { return NO; }
+ (NSURL *)requiredAuthURL { return nil; }
+ (NSString *)domainSuffix { return @""; }

#pragma mark Account Persistence

+ (NSArray *)allAccounts {    
    if (!allAccounts) {
        // initial load
        NSArray *accountDicts = [[NSUserDefaults standardUserDefaults] objectForKey:@"accounts"];
        NSArray *accounts = [accountDicts selectUsingBlock:^id(NSDictionary *dict) { return [Account accountWithDictionary:dict]; }];
        allAccounts = [accounts mutableCopy]; // retained
    }
    
    // no saved data?
    if (!allAccounts)
        allAccounts = [NSMutableArray new]; // retained
    
    return allAccounts;
}

+ (void)saveAccounts {
    NSArray *accounts = [allAccounts valueForKey:@"dictionaryRepresentation"];
    [[NSUserDefaults standardUserDefaults] setObject:accounts forKey:@"accounts"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:kAccountsChangedNotification object:nil];
}

+ (void)addAccount:(Account *)account {
    [allAccounts addObject:account];
    [self saveAccounts];
}

+ (void)removeAccount:(Account *)account {
    [allAccounts removeObject:account];
    [self saveAccounts];
}

#pragma mark Account Implementation

+ (Account *)accountWithDictionary:(NSDictionary *)dict {
    NSString *type = [dict objectForKey:@"type"];
    Class class = NSClassFromString([type stringByAppendingString:@"Account"]);
    return [[[class alloc] initWithDictionary:dict] autorelease];
}

- (id)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    self.domain = [dict objectForKey:@"domain"];
    self.username = [dict objectForKey:@"username"];
    self.feeds = [[dict objectForKey:@"feeds"] selectUsingBlock:^id(NSDictionary *dict) { return [Feed feedWithDictionary:dict account:self]; }];
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:self.type forKey:@"type"];
    if (domain) [dict setObject:self.domain forKey:@"domain"];
    if (username) [dict setObject:self.username forKey:@"username"];
    if (feeds) [dict setObject:[feeds valueForKey:@"dictionaryRepresentation"] forKey:@"feeds"];
    return dict;
}

- (void)dealloc {
    self.delegate = nil;
    self.domain = self.username = nil;
    self.request = nil;
    self.feeds = nil;
    [super dealloc];
}

- (NSString *)type {
    return [NSStringFromClass([self class]) stringByReplacingOccurrencesOfString:@"Account" withString:@""];
}

- (NSImage *)menuIconImage {
    return [NSImage imageNamed:[self.type stringByAppendingString:@".png"]] ?: [NSImage imageNamed:@"Default.png"];
}

- (NSImage *)accountIconImage {
    return [NSImage imageNamed:[self.type stringByAppendingString:@"Account.png"]];
}

- (NSData *)notifyIconData {
    return [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:[self.type stringByAppendingString:@"Notify.png"]]];
}

- (const char *)serviceName {
    return [[self description] cStringUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)description {
    return [domain length] ? [self.type stringByAppendingFormat:@" (%@)",domain] : self.type;
}

- (void)validateWithPassword:(NSString *)password {
    // no default implementation
}

- (void)cancelValidation {
    self.request = nil;
}

- (void)authWasFinishedWithURL:(NSURL *)url {
    // no default implementation
}

- (NSString *)findPassword:(SecKeychainItemRef *)itemRef {
    const char *serviceName = [self serviceName];
    void *passwordData;
    UInt32 passwordLength;
    
    OSStatus status = SecKeychainFindGenericPassword(NULL,
                                                     (UInt32)strlen(serviceName), serviceName,
                                                     (UInt32)[username lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [username UTF8String],
                                                     &passwordLength, &passwordData,
                                                     itemRef);
    
    if (status != noErr) {
        NSLog(@"Find password failed. (OSStatus: %d)\n", (int)status);
        return nil;
    }
    
    NSString *password = [[[NSString alloc] initWithBytes:passwordData length:passwordLength encoding:NSUTF8StringEncoding] autorelease];
    SecKeychainItemFreeContent(NULL, passwordData);
    return password;
}

- (NSString *)findPassword {
    return [self findPassword:NULL];
}

- (void)savePassword:(NSString *)password {
    
    if ([password length] == 0) {
        [self deletePassword];
        return;
    }

    SecKeychainItemRef itemRef;
    
    if ([self findPassword:&itemRef]) {
        
        OSStatus status = SecKeychainItemModifyAttributesAndData(itemRef,NULL,
                                                                 (UInt32)[password lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                                                 [password UTF8String]);
        
        if (status != noErr)
            NSLog(@"Update password failed. (OSStatus: %d)\n", (int)status);
    }
    else {
        const char *serviceName = [self serviceName];
        
        OSStatus status = SecKeychainAddGenericPassword (NULL,
                                                         (UInt32)strlen(serviceName), serviceName,
                                                         (UInt32)[username lengthOfBytesUsingEncoding: NSUTF8StringEncoding],
                                                         [username UTF8String],
                                                         (UInt32)[password lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                                         [password UTF8String],
                                                         NULL);
        
        if (status != noErr)
            NSLog(@"Add password failed. (OSStatus: %d)\n", (int)status);
    }
}

- (void)deletePassword {
    SecKeychainItemRef itemRef;
    if ([self findPassword:&itemRef])
        SecKeychainItemDelete(itemRef);
}

#pragma mark NSTableViewDataSource, exposes Feeds

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return feeds.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Feed *feed = [feeds objectAtIndex:row];
    if ([tableColumn.identifier isEqual:@"showColumn"])
        return [NSNumber numberWithBool:!feed.disabled];
    else if ([tableColumn.identifier isEqual:@"feedColumn"])
        return feed.title;
    else
        return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Feed *feed = [feeds objectAtIndex:row];
    if ([tableColumn.identifier isEqual:@"showColumn"]) {
        feed.disabled = ![object boolValue];
        [Account saveAccounts];
    }
}

@end
