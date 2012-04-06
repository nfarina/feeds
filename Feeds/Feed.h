
@class Account;

extern NSString *kFeedUpdatedNotification;

NSDate *AutoFormatDate(NSString *dateString);

@interface Feed : NSObject {
    NSURL *URL;
    NSString *title, *author;
    NSArray *items; // of FeedItem
    SMWebRequest *request;
    BOOL disabled, requiresBasicAuth, requiresOAuth2Token;
    Account *account; // not retained
}
@property (nonatomic, retain) NSURL *URL;
@property (nonatomic, copy) NSString *title, *author;
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, assign) BOOL disabled, requiresBasicAuth, requiresOAuth2Token;
@property (nonatomic, assign) Account *account;

+ (Feed *)feedWithURLString:(NSString *)URLString title:(NSString *)title account:(Account *)account;
+ (Feed *)feedWithURLString:(NSString *)URLString title:(NSString *)title author:(NSString *)author account:(Account *)account;

+ (Feed *)feedWithDictionary:(NSDictionary *)dict account:(Account *)account;
- (NSDictionary *)dictionaryRepresentation;

- (void)refresh;

@end

@interface FeedItem : NSObject {
    NSString *title, *author, *authorIdentifier, *content, *strippedContent, *rawDate, *project;
    NSURL *link, *comments;
    NSDate *published, *updated;
    BOOL notified, viewed, authoredByMe;
    Feed *feed; // not retained
}
@property (nonatomic, copy) NSString *title, *author, *authorIdentifier, *project, *content, *rawDate;
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
