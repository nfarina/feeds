
@class Account;

extern NSString *kFeedUpdatedNotification;

NSDate *AutoFormatDate(NSString *dateString);

@interface Feed : NSObject

// stored properties
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, copy) NSString *title, *author;
@property (nonatomic, copy) NSDictionary *requestHeaders;
@property (nonatomic, assign) BOOL disabled, requiresBasicAuth, requiresOAuth2Token, incremental;

// used only at runtime
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, weak) Account *account;

+ (Feed *)feedWithURLString:(NSString *)URLString title:(NSString *)title account:(Account *)account;
+ (Feed *)feedWithURLString:(NSString *)URLString title:(NSString *)title author:(NSString *)author account:(Account *)account;

+ (Feed *)feedWithDictionary:(NSDictionary *)dict account:(Account *)account;
- (NSDictionary *)dictionaryRepresentation;

+ (NSArray *)feedItemsWithData:(NSData *)data discoveredTitle:(NSString **)title error:(NSError **)error;

- (void)refresh;
- (void)refreshWithURL:(NSURL *)refreshURL; // some accounts (like basecamp next) append things like "since=" to the "base" URL

@end

@interface FeedItem : NSObject

@property (nonatomic, copy) NSString *identifier, *title, *author, *authorIdentifier, *project, *content, *rawDate;
@property (nonatomic, strong) NSURL *link, *comments;
@property (nonatomic, strong) NSDate *published, *updated;
@property (nonatomic, assign) BOOL notified, viewed, authoredByMe;
@property (nonatomic, weak) Feed *feed;

@property (weak, nonatomic, readonly) NSString *authorAndTitle;

// creates a new FeedItem by parsing an XML element
+ (FeedItem *)itemWithRSSItemElement:(SMXMLElement *)element;
+ (FeedItem *)itemWithATOMEntryElement:(SMXMLElement *)element;

- (NSComparisonResult)compareItemByPublishedDate:(FeedItem *)item;

- (NSAttributedString *)attributedStringHighlighted:(BOOL)highlighted;

@end
