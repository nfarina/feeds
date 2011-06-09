#import "RSSItem.h"

@implementation RSSItem
@synthesize title, link, comments;

+ (RSSItem *)itemWithElement:(SMXMLElement *)element {
    RSSItem *item = [[RSSItem new] autorelease];
    item.title = [element childNamed:@"title"].value;

    if ([element childNamed:@"link"])
        item.link = [NSURL URLWithString:[element childNamed:@"link"].value];

    if ([element childNamed:@"comments"])
        item.comments = [NSURL URLWithString:[element childNamed:@"comments"].value];

    return item;
}

- (void)dealloc {
    self.title = nil;
    self.link = nil;
    [super dealloc];
}

+ (SMWebRequest *)requestForItemsWithURL:(NSURL *)URL {
    
    // Set ourself as the background processing delegate. The caller can still add herself as a listener for the resulting data.
    return [SMWebRequest requestWithURL:URL
                               delegate:(id<SMWebRequestDelegate>)self 
                                context:nil];
}

// This method is called on a background thread. Don't touch your instance members!
+ (id)webRequest:(SMWebRequest *)webRequest resultObjectForData:(NSData *)data context:(id)context {

    // We do this gnarly parsing on a background thread to keep the UI responsive.
    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:NULL];
    
    // Select the bits in which we're interested.
    NSArray *itemsXml = [[document.root childNamed:@"channel"] childrenNamed:@"item"];

    NSMutableArray *items = [NSMutableArray array];
    
    // Convert them into model objects
    for (SMXMLElement *itemXml in itemsXml)
        [items addObject:[RSSItem itemWithElement:itemXml]];
    
    return items;
}

@end
