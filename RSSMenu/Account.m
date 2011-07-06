#import "Account.h"

@interface Account ()
- (NSString *)simpleName;
@end

@implementation Account
@synthesize delegate, domain, username, request;

+ (Account *)accountWithDictionary:(NSDictionary *)dict {
    NSString *type = [dict objectForKey:@"type"];
    Class class = NSClassFromString([type stringByAppendingString:@"Account"]);
    return [[[class alloc] initWithDictionary:dict] autorelease];
}

- (id)initWithDictionary:(NSDictionary *)dict {
    if ([super init]) {
        self.domain = [dict objectForKey:@"domain"];
        self.username = [dict objectForKey:@"username"];
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [self simpleName], @"type",
            domain, @"domain",
            username, @"username",
            nil];
}

- (void)dealloc {
    self.delegate = nil;
    self.domain = self.username;
    self.request = nil;
    [super dealloc];
}

- (void)setRequest:(SMWebRequest *)value {
    [request removeTarget:self];
    [request release], request = [value retain];
}

- (NSString *)simpleName {
    return [NSStringFromClass([self class]) stringByReplacingOccurrencesOfString:@"Account" withString:@""];
}

- (const char *)serviceName {
    return [[self description] cStringUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)description {
    return [domain length] ? [[self simpleName] stringByAppendingFormat:@" (%@)",domain] : [self simpleName];
}

- (void)validateWithPassword:(NSString *)password {
    // no default implementation
}

- (NSString *)findPassword {
    if (username) {
        const char *serviceName = [self serviceName];
        void *passwordData;
        UInt32 passwordLength;
        
        OSStatus status = SecKeychainFindGenericPassword(
                                                         NULL,           // default keychain
                                                         (UInt32)strlen(serviceName),             // length of service name
                                                         serviceName,   // service name
                                                         (UInt32)[username lengthOfBytesUsingEncoding:NSUTF8StringEncoding], // length of account name
                                                         [username UTF8String],   // account name
                                                         &passwordLength,  // length of password
                                                         &passwordData,   // pointer to password data
                                                         NULL // the item reference
                                                         );
        
        if (status != noErr) {
            NSLog(@"SecKeychainFindGenericPassword: failed. (OSStatus: %d)\n", status); // FIXME: handle the errror
            return nil;//@"";
        }
        
        NSString *passwd = [[NSString alloc] initWithBytes: passwordData length: passwordLength encoding: NSUTF8StringEncoding];
        status = SecKeychainItemFreeContent(NULL, passwordData);
        
        if (status != noErr)
            NSLog(@"SeSecKeychainItemFreeContent: failed. (OSStatus: %d)\n", status); // FIXME: handle the errror
        
        return passwd;
    }
    else
        return nil;
}

- (void)savePassword:(NSString *)password {
    [self deletePassword];
    if (username) {
        const char *serviceName = [self serviceName];
        OSStatus status = SecKeychainAddGenericPassword (
                                                         NULL,           // default keychain
                                                         (UInt32)strlen(serviceName),             // length of service name
                                                         serviceName,   // service name
                                                         (UInt32)[username lengthOfBytesUsingEncoding: NSUTF8StringEncoding], // length of account name
                                                         [username UTF8String],   // account name
                                                         (UInt32)[password lengthOfBytesUsingEncoding:NSUTF8StringEncoding], // length of password
                                                         [password UTF8String],   // password
                                                         NULL
                                                         );
        
        if (status != noErr)
            NSLog(@"SecKeychainAddGenericPassword: failed. (OSStatus: %d)\n", status); // FIXME: handle the errror
    }
}

- (void)deletePassword {
    if (username) {
        const char *serviceName = [self serviceName];
        void *passwordData;
        UInt32 passwordLength;
        SecKeychainItemRef itemRef;
        
        OSStatus status = SecKeychainFindGenericPassword(
                                                         NULL,           // default keychain
                                                         (UInt32)strlen(serviceName),             // length of service name
                                                         serviceName,   // service name
                                                         (UInt32)[username lengthOfBytesUsingEncoding:NSUTF8StringEncoding], // length of account name
                                                         [username UTF8String],   // account name
                                                         &passwordLength,  // length of password
                                                         &passwordData,   // pointer to password data
                                                         &itemRef // the item reference
                                                         );
        
        if (status != noErr) {
            NSLog(@"SecKeychainFindGenericPassword: failed. (OSStatus: %d)\n", status); // FIXME: handle the errror
            return;
        }
        
        SecKeychainItemFreeContent(NULL, passwordData);
        SecKeychainItemDelete(itemRef);
    }
}

@end
