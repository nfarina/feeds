
@protocol AccountDelegate;

@interface Account : NSObject {
    id<AccountDelegate> delegate; // nonretained
    NSString *domain, *username, *password;
    SMWebRequest *request; // convenience for subclassers, will be properly cancelled and cleaned up on dealloc
}

@property (nonatomic, assign) id<AccountDelegate> delegate;
@property (nonatomic, copy) NSString *domain, *username, *password;
@property (nonatomic, retain) SMWebRequest *request;

- (const char *)serviceName;

- (void)validate;

@end


@protocol AccountDelegate <NSObject>

- (void)accountValidationDidComplete:(Account *)account;

@end