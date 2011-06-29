#import "Account.h"

#define SERVICE_NAME "RSSMenu"

@implementation Account
@synthesize username;

- (void)dealloc {
    self.username = nil;
    [super dealloc];
}

- (NSString *)password {
    if (username) {
        void *passwordData;
        UInt32 passwordLength;
        OSStatus status = SecKeychainFindGenericPassword(
                                                         NULL,           // default keychain
                                                         strlen(SERVICE_NAME),             // length of service name
                                                         SERVICE_NAME,   // service name
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

- (void)setPassword:(NSString *)value {
    if (username) {
        OSStatus status = SecKeychainAddGenericPassword (
                                                         NULL,           // default keychain
                                                         strlen(SERVICE_NAME),             // length of service name
                                                         SERVICE_NAME,   // service name
                                                         (UInt32)[username lengthOfBytesUsingEncoding: NSUTF8StringEncoding], // length of account name
                                                         [username UTF8String],   // account name
                                                         (UInt32)[value lengthOfBytesUsingEncoding:NSUTF8StringEncoding], // length of password
                                                         [value UTF8String],   // password
                                                         NULL
                                                         );
        
        if (status != noErr)
            NSLog(@"SecKeychainAddGenericPassword: failed. (OSStatus: %d)\n", status); // FIXME: handle the errror
    }
}

@end
