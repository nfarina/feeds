
extern NSString *kRSSFeedUpdatedNotification;

@interface RSSFeed : NSObject {
    NSURL *URL;
    NSArray *items; // of RSSItem
    SMWebRequest *request;
}
@property (nonatomic, retain) NSURL *URL;
@property (nonatomic, copy) NSArray *items;

- (void)refresh;

@end

@interface RSSItem : NSObject {
    NSString *title, *author, *content;
    NSURL *link, *comments;
    NSDate *published, *updated;
}
@property (nonatomic, copy) NSString *title, *author, *content;
@property (nonatomic, retain) NSURL *link, *comments;
@property (nonatomic, retain) NSDate *published, *updated;

// creates a new RSSItem by parsing an XML element
+ (RSSItem *)itemWithRSSItemElement:(SMXMLElement *)element formatter:(NSDateFormatter *)formatter;
+ (RSSItem *)itemWithATOMEntryElement:(SMXMLElement *)element formatter:(NSDateFormatter *)formatter;

- (NSComparisonResult)compareItemByPublishedDate:(RSSItem *)item;

@end
