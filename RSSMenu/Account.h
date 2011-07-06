
typedef enum {
    AccountFailingFieldUnknown,
    AccountFailingFieldDomain,
    AccountFailingFieldUsername,
    AccountFailingFieldPassword
} AccountFailingField;

@protocol AccountDelegate;

@interface Account : NSObject {
    id<AccountDelegate> delegate; // nonretained
    NSString *domain, *username;
    SMWebRequest *request; // convenience for subclassers, will be properly cancelled and cleaned up on dealloc
}

@property (nonatomic, assign) id<AccountDelegate> delegate;
@property (nonatomic, copy) NSString *domain, *username;
@property (nonatomic, retain) SMWebRequest *request;

+ (NSArray *)allAccounts;
+ (void)addAccount:(Account *)account;
+ (void)removeAccount:(Account *)account;

- (id)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;

- (void)validateWithPassword:(NSString *)password;

- (NSString *)findPassword;
- (void)savePassword:(NSString *)password;
- (void)deletePassword;

@property (nonatomic, readonly) NSString *type;

@end


@protocol AccountDelegate <NSObject>

- (void)account:(Account *)account validationDidContinueWithMessage:(NSString *)message;
- (void)account:(Account *)account validationDidFailWithMessage:(NSString *)message field:(AccountFailingField)field;
- (void)accountValidationDidComplete:(Account *)account;

@end