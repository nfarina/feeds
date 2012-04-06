#import "Feed.h"

extern NSString *kAccountsChangedNotification;

typedef enum {
    AccountFailingFieldUnknown,
    AccountFailingFieldDomain,
    AccountFailingFieldUsername,
    AccountFailingFieldPassword,
    AccountFailingFieldAuth,
} AccountFailingField;

@protocol AccountDelegate;

@interface Account : NSObject <NSTableViewDataSource> {
    id<AccountDelegate> delegate; // nonretained
    NSString *domain, *username;
    SMWebRequest *request; // convenience for subclassers, will be properly cancelled and cleaned up on dealloc
    SMWebRequest *tokenRequest; // similar convenience for subclasses who need to refresh oauth tokens.
    NSArray *feeds; // of Feed
}

// discriminator
@property (nonatomic, readonly) NSString *type;

+ (NSArray *)registeredClasses; // of Class
+ (void)registerClass:(Class)cls;
+ (NSString *)friendlyAccountName; // default implementation chops off the Account suffix
+ (NSString *)shortAccountName; // for display in the list-of-accounts table view, defaults to +friendlyAccountName

// creation options, returns YES by default
+ (BOOL) requiresAuth;
+ (BOOL) requiresDomain;
+ (BOOL) requiresUsername;
+ (BOOL) requiresPassword;

// "new feed" dialog customizations
+ (NSString *)domainLabel;
+ (NSString *)domainPrefix;
+ (NSString *)domainSuffix;

// opportunity to parse custom feed data
+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password;

// helper for said opportunity (threadsafe)
+ (NSData *)extraDataWithContentsOfURL:(NSURL *)URL;
+ (NSData *)extraDataWithContentsOfURLRequest:(NSMutableURLRequest *)URLRequest;

@property (nonatomic, assign) id<AccountDelegate> delegate;
@property (nonatomic, copy) NSString *domain, *username;
@property (nonatomic, copy) NSArray *feeds;
@property (nonatomic, readonly) NSImage *menuIconImage, *accountIconImage;
@property (nonatomic, readonly) NSData *notifyIconData;
@property (nonatomic, readonly) NSArray *enabledFeeds;

+ (NSArray *)allAccounts;
+ (void)addAccount:(Account *)account;
+ (void)removeAccount:(Account *)account;
+ (void)saveAccounts;
+ (void)saveAccountsAndNotify:(BOOL)notify;

- (id)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;

- (void)validateWithPassword:(NSString *)password;
- (void)cancelValidation;

- (void)beginAuth;
- (void)authWasFinishedWithURL:(NSURL *)url;

- (NSString *)findPassword;
- (void)savePassword:(NSString *)password;
- (void)deletePassword;

- (void)refreshEnabledFeeds;
- (void)refreshFeeds:(NSArray *)feeds;

// for subclassers
@property (nonatomic, retain) SMWebRequest *request, *tokenRequest;

@end


@protocol AccountDelegate <NSObject>

- (void)account:(Account *)account validationDidContinueWithMessage:(NSString *)message;
- (void)account:(Account *)account validationDidFailWithMessage:(NSString *)message field:(AccountFailingField)field;
- (void)account:(Account *)account validationDidCompleteWithPassword:(NSString *)password;

@end