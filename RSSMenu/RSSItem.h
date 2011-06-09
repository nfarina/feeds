#import "SMXMLDocument.h"
#import "SMWebRequest.h"

@interface RSSItem : NSObject {
    NSString *title;
    NSURL *link, *comments;
}
@property (nonatomic, copy) NSString *title;
@property (nonatomic, retain) NSURL *link, *comments;

// creates a new Item by parsing an XML element
+ (RSSItem *)itemWithElement:(SMXMLElement *)element;

// creates a new request that will result in an NSArray of Items.
+ (SMWebRequest *)requestForItemsWithURL:(NSURL *)URL;

@end
