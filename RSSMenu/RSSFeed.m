#import "RSSFeed.h"

NSString *kRSSFeedUpdatedNotification = @"RSSFeedUpdatedNotification";

@interface RSSFeed ()
@property (nonatomic, retain) SMWebRequest *request;
@end

@implementation RSSFeed
@synthesize URL, items, request;

- (void)dealloc {
    self.URL = nil;
    self.items = nil;
    self.request = nil;
    [super dealloc];
}

- (void)setRequest:(SMWebRequest *)value {
    [request removeTarget:self];
    request = [value retain];
}

+ (RSSFeed *)feedWithDictionary:(NSDictionary *)dict {
    RSSFeed *feed = [[[RSSFeed alloc] init] autorelease];
    feed.URL = [NSURL URLWithString:[dict objectForKey:@"url"]];
    return feed;
}

- (void)refresh {
    self.request = [SMWebRequest requestWithURL:self.URL delegate:(id<SMWebRequestDelegate>)[self class] context:nil];
    [request addTarget:self action:@selector(refreshComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request start];
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

- (void)refreshComplete:(NSArray *)newItems {
    self.items = newItems;
    [[NSNotificationCenter defaultCenter] postNotificationName:kRSSFeedUpdatedNotification object:self];
}

@end

@implementation RSSItem
@synthesize title, link, comments;

- (void)dealloc {
    self.title = nil;
    self.link = self.comments = nil;
    [super dealloc];
}

+ (RSSItem *)itemWithElement:(SMXMLElement *)element {
    RSSItem *item = [[RSSItem new] autorelease];
    item.title = [element childNamed:@"title"].value;

    if ([element childNamed:@"link"])
        item.link = [NSURL URLWithString:[element childNamed:@"link"].value];

    if ([element childNamed:@"comments"])
        item.comments = [NSURL URLWithString:[element childNamed:@"comments"].value];

    return item;
}

@end
