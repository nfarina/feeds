
@class Account;

extern NSString *kFeedUpdatedNotification;

NSDate *AutoFormatDate(NSString *dateString);

@interface Feed : NSObject {
    // stored properties
    NSURL *URL;
    NSString *title, *author;
    BOOL disabled, requiresBasicAuth, requiresOAuth2Token, incremental;
    NSDictionary *requestHeaders; // some authentication systems want tokens and stuff in the headers

    // used only at runtime
    SMWebRequest *request;
    NSArray *items; // of FeedItem
    Account *account; // not retained
}
@property (nonatomic, retain) NSURL *URL;
@property (nonatomic, copy) NSString *title, *author;
@property (nonatomic, copy) NSDictionary *requestHeaders;
@property (nonatomic, assign) BOOL disabled, requiresBasicAuth, requiresOAuth2Token, incremental;
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, assign) Account *account;

+ (Feed *)feedWithURLString:(NSString *)URLString title:(NSString *)title account:(Account *)account;
+ (Feed *)feedWithURLString:(NSString *)URLString title:(NSString *)title author:(NSString *)author account:(Account *)account;

+ (Feed *)feedWithDictionary:(NSDictionary *)dict account:(Account *)account;
- (NSDictionary *)dictionaryRepresentation;

+ (NSArray *)feedItemsWithData:(NSData *)data discoveredTitle:(NSString **)title error:(NSError **)error;

- (void)refresh;
- (void)refreshWithURL:(NSURL *)refreshURL; // some accounts (like basecamp next) append things like "since=" to the "base" URL

@end

@interface FeedItem : NSObject {
    NSString *identifier, *title, *author, *authorIdentifier, *content, *strippedContent, *rawDate, *project; // not all items have identifiers
    NSURL *link, *comments;
    NSDate *published, *updated;
    BOOL notified, viewed, authoredByMe;
    Feed *feed; // not retained
}
@property (nonatomic, copy) NSString *identifier, *title, *author, *authorIdentifier, *project, *content, *rawDate;
@property (nonatomic, retain) NSURL *link, *comments;
@property (nonatomic, retain) NSDate *published, *updated;
@property (nonatomic, assign) BOOL notified, viewed, authoredByMe;
@property (nonatomic, assign) Feed *feed;

@property (nonatomic, readonly) NSString *authorAndTitle;

// creates a new FeedItem by parsing an XML element
+ (FeedItem *)itemWithRSSItemElement:(SMXMLElement *)element;
+ (FeedItem *)itemWithATOMEntryElement:(SMXMLElement *)element;

- (NSComparisonResult)compareItemByPublishedDate:(FeedItem *)item;

- (NSAttributedString *)attributedStringHighlighted:(BOOL)highlighted;

@end
