#import "RSSFeed.h"

NSString *kRSSFeedUpdatedNotification = @"RSSFeedUpdatedNotification";

NSDateFormatter *RSSDateFormatter() {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    return formatter;
}

NSDateFormatter *ATOMDateFormatter() {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    return formatter;
}

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
    
    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:NULL];
    NSMutableArray *items = [NSMutableArray array];

    // are we speaking RSS or ATOM here?
    if ([document.root.name isEqual:@"rss"]) {

        NSArray *itemsXml = [[document.root childNamed:@"channel"] childrenNamed:@"item"];
        NSDateFormatter *formatter = RSSDateFormatter();
        
        for (SMXMLElement *itemXml in itemsXml)
            [items addObject:[RSSItem itemWithRSSItemElement:itemXml formatter:formatter]];
    }
    else if ([document.root.name isEqual:@"feed"]) {

        NSArray *itemsXml = [document.root childrenNamed:@"entry"];
        NSDateFormatter *formatter = ATOMDateFormatter();
        
        for (SMXMLElement *itemXml in itemsXml)
            [items addObject:[RSSItem itemWithATOMEntryElement:itemXml formatter:formatter]];

    }
    else NSLog(@"Unknown feed root element: <%@>", document.root.name);
        
    return items;
}

- (void)refreshComplete:(NSArray *)newItems {
    
    NSMutableArray *merged = [NSMutableArray array];
    
    for (RSSItem *newItem in newItems) {
        int i = (int)[items indexOfObject:newItem];
        if (items != nil && i >= 0)
            [merged addObject:[items objectAtIndex:i]]; // preserve existing item
        else
            [merged addObject:newItem];
    }
    
    self.items = merged;
    [[NSNotificationCenter defaultCenter] postNotificationName:kRSSFeedUpdatedNotification object:self];
}

@end

@implementation RSSItem
@synthesize title, author, content, strippedContent, link, comments, published, updated, notified;

- (void)dealloc {
    self.title = self.author = self.content = self.strippedContent = nil;
    self.link = self.comments = nil;
    self.published = self.updated = nil;
    [super dealloc];
}

+ (RSSItem *)itemWithRSSItemElement:(SMXMLElement *)element formatter:(NSDateFormatter *)formatter {
    RSSItem *item = [[RSSItem new] autorelease];
    item.title = [element childNamed:@"title"].value;
    item.author = [element childNamed:@"author"].value;
    item.content = [element childNamed:@"description"].value;
    item.strippedContent = [[item.content stringByFlatteningHTML] stringByCondensingSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([element childNamed:@"link"])
        item.link = [NSURL URLWithString:[element childNamed:@"link"].value];
    
    if ([element childNamed:@"comments"])
        item.comments = [NSURL URLWithString:[element childNamed:@"comments"].value];
    
    item.published = [formatter dateFromString:[element childNamed:@"pubDate"].value];
    item.updated = item.published;
    
    return item;
}

+ (RSSItem *)itemWithATOMEntryElement:(SMXMLElement *)element formatter:(NSDateFormatter *)formatter {
    RSSItem *item = [[RSSItem new] autorelease];
    item.title = [element childNamed:@"title"].value;
    item.author = [element valueWithPath:@"author.name"];
    item.content = [element childNamed:@"content"].value;
    item.strippedContent = [[item.content stringByFlatteningHTML] stringByCondensingSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSString *linkHref = [[element childNamed:@"link"] attributeNamed:@"href"];
    
    if (linkHref.length)
        item.link = [NSURL URLWithString:linkHref];
    
    item.published = [formatter dateFromString:[element childNamed:@"published"].value];
    item.updated = [formatter dateFromString:[element childNamed:@"updated"].value];
    
    return item;
}

- (BOOL)isEqual:(RSSItem *)other {
    if ([other isKindOfClass:[RSSItem class]]) {
        return [link isEqual:other.link] && [updated isEqual:other.updated];
    }
    else return NO;
}

- (NSComparisonResult)compareItemByPublishedDate:(RSSItem *)item {
    return [item.published compare:self.published];
}

@end
