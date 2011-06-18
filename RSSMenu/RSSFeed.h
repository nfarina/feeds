
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
    NSString *title;
    NSURL *link, *comments;
}
@property (nonatomic, copy) NSString *title;
@property (nonatomic, retain) NSURL *link, *comments;

// creates a new RSSItem by parsing an XML element
+ (RSSItem *)itemWithElement:(SMXMLElement *)element;

@end
