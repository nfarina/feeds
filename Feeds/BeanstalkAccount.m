#import "BeanstalkAccount.h"

@implementation BeanstalkAccount

//+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresDomain { return YES; }
+ (BOOL)requiresUsername { return NO; }
+ (BOOL)requiresPassword { return NO; }

- (void)validateWithPassword:(NSString *)password {
    [self.delegate account:self validationDidCompleteWithPassword:nil];
}

@end
