#import "Account.h"

NSString *kAccountsChangedNotification = @"AccountsChangedNotification";

static NSMutableArray *allAccounts = nil;

@implementation Account

static NSMutableArray *registeredClasses = nil;

+ (NSArray *)registeredClasses { 
    NSArray *descriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"friendlyAccountName" ascending:YES]];
    return [registeredClasses sortedArrayUsingDescriptors:descriptors];
}
+ (void)registerClass:(Class)cls {
    if (!registeredClasses) registeredClasses = [NSMutableArray new];
    [registeredClasses addObject:cls];
}

// threadsafe
+ (NSData *)extraDataWithContentsOfURL:(NSURL *)URL {
    return [self extraDataWithContentsOfURLRequest:[NSMutableURLRequest requestWithURL:URL]];
}

+ (NSData *)extraDataWithContentsOfURLRequest:(NSMutableURLRequest *)request {
    static NSMutableDictionary *cache = nil;
    
    @synchronized (self) {
        if (!cache) cache = [NSMutableDictionary new];
        NSData *result = cache[request.URL];
        if (result) return result;
    }

    request.timeoutInterval = 5; // we could have a lot of these requests to make, don't let it take too long
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (error)
        DDLogError(@"Error while fetching extra data at (%@): %@", request.URL, error);
    else {
        DDLogInfo(@"Fetched extra for %@", NSStringFromClass(self));
        @synchronized (self) {
            cache[request.URL] = data;
        }
    }
    
    return data;
}

+ (NSString *)friendlyAccountName {
    return [NSStringFromClass(self) stringByReplacingOccurrencesOfString:@"Account" withString:@""];
}

+ (NSString *)shortAccountName {
    return [self friendlyAccountName];
}

+ (BOOL)requiresAuth { return NO; }
+ (BOOL)requiresDomain { return NO; }
+ (BOOL)requiresUsername { return NO; }
+ (BOOL)requiresPassword { return NO; }
+ (NSString *)usernameLabel { return @"User name:"; }
+ (NSString *)passwordLabel { return @"Password:"; }
+ (NSString *)domainLabel { return @"Domain:"; }
+ (NSString *)domainPrefix { return @"http://"; }
+ (NSString *)domainSuffix { return @""; }
+ (NSString *)domainPlaceholder { return @""; }
+ (NSTimeInterval)defaultRefreshInterval { return 10*60; } // 10 minutes

- (NSArray *)enabledFeeds {
    NSMutableArray *enabledFeeds = [NSMutableArray array];
    for (Feed *feed in self.feeds)
        if (!feed.disabled)
            [enabledFeeds addObject:feed];
    return enabledFeeds;
}

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

+ (void)saveAccounts { [self saveAccountsAndNotify:YES]; }

+ (void)saveAccountsAndNotify:(BOOL)notify {
#ifndef EXPIRATION_DATE
    NSArray *accounts = [allAccounts valueForKey:@"dictionaryRepresentation"];
    [[NSUserDefaults standardUserDefaults] setObject:accounts forKey:@"accounts"];
    [[NSUserDefaults standardUserDefaults] synchronize];
#endif
    if (notify)
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
    NSString *type = dict[@"type"];
    Class class = NSClassFromString([type stringByAppendingString:@"Account"]);
    return [[class alloc] initWithDictionary:dict];
}

- (id)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    self.name = dict[@"name"];
    self.domain = dict[@"domain"];
    self.username = dict[@"username"];
    self.refreshInterval = [dict[@"refreshInterval"] integerValue];
    self.feeds = [dict[@"feeds"] selectUsingBlock:^id(NSDictionary *dict) { return [Feed feedWithDictionary:dict account:self]; }];
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"type"] = self.type;
    if (self.name) dict[@"name"] = self.name;
    if (self.domain) dict[@"domain"] = self.domain;
    if (self.username) dict[@"username"] = self.username;
    if (self.refreshInterval) dict[@"refreshInterval"] = @(self.refreshInterval);
    if (self.feeds) dict[@"feeds"] = [self.feeds valueForKey:@"dictionaryRepresentation"];
    return dict;
}

- (void)dealloc {
    self.delegate = nil;
    self.request = self.tokenRequest = nil;
}

- (void)setRequest:(SMWebRequest *)request_ {
    [_request removeTarget:self];
    _request = request_;
}

- (void)setTokenRequest:(SMWebRequest *)tokenRequest_ {
    [_tokenRequest removeTarget:self];
    _tokenRequest = tokenRequest_;
}

- (NSString *)type {
    return [NSStringFromClass([self class]) stringByReplacingOccurrencesOfString:@"Account" withString:@""];
}

- (NSString *)iconPrefix { return self.type; }

- (NSImage *)menuIconImage {
    return [NSImage imageNamed:[self.iconPrefix stringByAppendingString:@".tiff"]] ?: [NSImage imageNamed:@"Default.tiff"];
}

- (NSImage *)accountIconImage {
    return [NSImage imageNamed:[self.iconPrefix stringByAppendingString:@"Account.tiff"]];
}

- (NSData *)notifyIconData {
    return [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:[self.iconPrefix stringByAppendingString:@"Notify.tiff"]]];
}

- (const char *)serviceName {
    return [[self description] cStringUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)description {
    return [self.domain length] ? [self.type stringByAppendingFormat:@" (%@)",self.friendlyDomain] : self.type;
}

- (NSString *)friendlyDomain {
    if ([self.domain beginsWithString:@"http://"] || [self.domain beginsWithString:@"https://"]) {
        NSURL *URL = [NSURL URLWithString:self.domain];
        return URL.host;
    }
    else return self.domain;
}

- (NSTimeInterval)refreshIntervalOrDefault {
    return self.refreshInterval ?: [[self class] defaultRefreshInterval];
}

- (void)validateWithPassword:(NSString *)password {
    // no default implementation
}

- (void)cancelValidation {
    self.request = nil;
}

- (void)beginAuth {
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
                                                     (UInt32)[self.username lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [self.username UTF8String],
                                                     &passwordLength, &passwordData,
                                                     itemRef);
    
    if (status != noErr) {
        if (status != errSecItemNotFound)
            DDLogWarn(@"Find password failed for account %@. (OSStatus: %d)\n", self, (int)status);
        return nil;
    }
    
    NSString *password = [[NSString alloc] initWithBytes:passwordData length:passwordLength encoding:NSUTF8StringEncoding];
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
            DDLogError(@"Update password failed. (OSStatus: %d)\n", (int)status);
    }
    else {
        const char *serviceName = [self serviceName];
        
        OSStatus status = SecKeychainAddGenericPassword (NULL,
                                                         (UInt32)strlen(serviceName), serviceName,
                                                         (UInt32)[self.username lengthOfBytesUsingEncoding: NSUTF8StringEncoding],
                                                         [self.username UTF8String],
                                                         (UInt32)[password lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                                         [password UTF8String],
                                                         NULL);
        
        if (status != noErr)
            DDLogError(@"Add password failed. (OSStatus: %d)\n", (int)status);
    }
}

- (void)deletePassword {
    SecKeychainItemRef itemRef;
    if ([self findPassword:&itemRef])
        SecKeychainItemDelete(itemRef);
}

- (NSString *)smartContentForItem:(FeedItem *)item {
    [self doesNotRecognizeSelector:@selector(smartContentForItem:)];
    return nil;
}

#pragma mark NSTableViewDataSource, exposes Feeds

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.feeds.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Feed *feed = (self.feeds)[row];
    if ([tableColumn.identifier isEqual:@"showColumn"])
        return @(!feed.disabled);
    else if ([tableColumn.identifier isEqual:@"feedColumn"])
        return feed.title;
    else
        return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Feed *feed = (self.feeds)[row];
    if ([tableColumn.identifier isEqual:@"showColumn"]) {
        feed.disabled = ![object boolValue];
        self.lastRefresh = nil; // force refresh on this feed
        [Account saveAccounts];
    }
}

#pragma mark Feed Refreshing

- (void)refreshEnabledFeeds {
    DDLogInfo(@"Refreshing feeds for account %@", self);
    self.lastRefresh = [NSDate date];
    [self refreshFeeds:self.enabledFeeds];
}

- (void)refreshFeeds:(NSArray *)feedsToRefresh {
    [feedsToRefresh makeObjectsPerformSelector:@selector(refresh)];
}

@end
