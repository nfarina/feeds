#import "Feed.h"

extern NSString *kAccountsChangedNotification;

typedef enum {
    AccountFailingFieldUnknown,
    AccountFailingFieldDomain,
    AccountFailingFieldUsername,
    AccountFailingFieldPassword
} AccountFailingField;

@protocol AccountDelegate;

@interface Account : NSObject <NSTableViewDataSource> {
    id<AccountDelegate> delegate; // nonretained
    NSString *domain, *username;
    SMWebRequest *request; // convenience for subclassers, will be properly cancelled and cleaned up on dealloc
    NSArray *feeds; // of Feed
}

// discriminator
@property (nonatomic, readonly) NSString *type;

// creation options, returns YES by default
+ (BOOL) requiresDomain;
+ (BOOL) requiresUsername;
+ (BOOL) requiresPassword;
+ (NSURL *) requiredAuthURL;
+ (NSString *)domainSuffix;

@property (nonatomic, assign) id<AccountDelegate> delegate;
@property (nonatomic, copy) NSString *domain, *username;
@property (nonatomic, copy) NSArray *feeds;
@property (nonatomic, readonly) NSImage *menuIconImage, *accountIconImage;
@property (nonatomic, readonly) NSData *notifyIconData;

+ (NSArray *)allAccounts;
+ (void)addAccount:(Account *)account;
+ (void)removeAccount:(Account *)account;
+ (void)saveAccounts;

- (id)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;

- (void)validateWithPassword:(NSString *)password;
- (void)cancelValidation;

- (NSString *)findPassword;
- (void)savePassword:(NSString *)password;
- (void)deletePassword;

// for subclassers
@property (nonatomic, retain) SMWebRequest *request;

@end


@protocol AccountDelegate <NSObject>

- (void)account:(Account *)account validationDidContinueWithMessage:(NSString *)message;
- (void)account:(Account *)account validationDidFailWithMessage:(NSString *)message field:(AccountFailingField)field;
- (void)accountValidationDidComplete:(Account *)account;

@end