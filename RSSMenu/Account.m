#import "Account.h"

@implementation Account
@synthesize delegate, domain, username, password, request;

- (void)dealloc {
    self.delegate = nil;
    self.domain = self.username = self.password = nil;
    self.request = nil;
    [super dealloc];
}

- (void)setRequest:(SMWebRequest *)value {
    [request removeTarget:self];
    [request release], request = [value retain];
}

- (const char *)serviceName { return "Unknown"; }

- (void)validate {
    // no default implementation
}

//- (NSString *)password {
//    if (username) {
//        const char *serviceName = [self serviceName];
//        void *passwordData;
//        UInt32 passwordLength;
//        
//        OSStatus status = SecKeychainFindGenericPassword(
//                                                         NULL,           // default keychain
//                                                         (UInt32)strlen(serviceName),             // length of service name
//                                                         serviceName,   // service name
//                                                         (UInt32)[username lengthOfBytesUsingEncoding:NSUTF8StringEncoding], // length of account name
//                                                         [username UTF8String],   // account name
//                                                         &passwordLength,  // length of password
//                                                         &passwordData,   // pointer to password data
//                                                         NULL // the item reference
//                                                         );
//        
//        if (status != noErr) {
//            NSLog(@"SecKeychainFindGenericPassword: failed. (OSStatus: %d)\n", status); // FIXME: handle the errror
//            return nil;//@"";
//        }
//        
//        NSString *passwd = [[NSString alloc] initWithBytes: passwordData length: passwordLength encoding: NSUTF8StringEncoding];
//        status = SecKeychainItemFreeContent(NULL, passwordData);
//        
//        if (status != noErr)
//            NSLog(@"SeSecKeychainItemFreeContent: failed. (OSStatus: %d)\n", status); // FIXME: handle the errror
//        
//        return passwd;
//    }
//    else
//        return nil;
//}
//
//- (void)setPassword:(NSString *)value {
//    if (username) {
//        const char *serviceName = [self serviceName];
//        OSStatus status = SecKeychainAddGenericPassword (
//                                                         NULL,           // default keychain
//                                                         (UInt32)strlen(serviceName),             // length of service name
//                                                         serviceName,   // service name
//                                                         (UInt32)[username lengthOfBytesUsingEncoding: NSUTF8StringEncoding], // length of account name
//                                                         [username UTF8String],   // account name
//                                                         (UInt32)[value lengthOfBytesUsingEncoding:NSUTF8StringEncoding], // length of password
//                                                         [value UTF8String],   // password
//                                                         NULL
//                                                         );
//        
//        if (status != noErr)
//            NSLog(@"SecKeychainAddGenericPassword: failed. (OSStatus: %d)\n", status); // FIXME: handle the errror
//    }
//}

@end
