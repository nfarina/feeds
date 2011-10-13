#import "Account.h"

NSString *kAccountsChangedNotification = @"AccountsChangedNotification";

static NSMutableArray *allAccounts = nil;

@interface Account ()
+ (Account *)accountWithDictionary:(NSDictionary *)dict;
@end

@implementation Account
@synthesize delegate, domain, username, request, feeds;

+ (BOOL)requiresDomain { return NO; }
+ (BOOL)requiresUsername { return NO; }
+ (BOOL)requiresPassword { return NO; }
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
    [super init];
    self.domain = [dict objectForKey:@"domain"];
    self.username = [dict objectForKey:@"username"];
    self.feeds = [[dict objectForKey:@"feeds"] selectUsingBlock:^id(NSDictionary *dict) { return [Feed feedWithDictionary:dict account:self]; }];
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            self.type, @"type",
            domain, @"domain",
            username, @"username",
            [feeds valueForKey:@"dictionaryRepresentation"], @"feeds",
            nil];
}

- (void)dealloc {
    self.delegate = nil;
    self.domain = self.username = nil;
    self.request = nil;
    [super dealloc];
}

- (void)setRequest:(SMWebRequest *)value {
    [request removeTarget:self];
    [request release], request = [value retain];
}

- (NSString *)type {
    return [NSStringFromClass([self class]) stringByReplacingOccurrencesOfString:@"Account" withString:@""];
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

@end
