#import "Feed.h"

NSString *kFeedUpdatedNotification = @"FeedUpdatedNotification";

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

@interface Feed ()
@property (nonatomic, retain) SMWebRequest *request;
@end

@implementation Feed
@synthesize URL, author, items, request;

- (void)dealloc {
    self.URL = nil;
    self.author = nil;
    self.items = nil;
    self.request = nil;
    [super dealloc];
}

- (void)setRequest:(SMWebRequest *)value {
    [request removeTarget:self];
    request = [value retain];
}

+ (Feed *)feedWithURLString:(NSString *)URLString {
    return [self feedWithURLString:URLString author:nil];
}

+ (Feed *)feedWithURLString:(NSString *)URLString author:(NSString *)author {
    Feed *feed = [[[Feed alloc] init] autorelease];
    feed.URL = [NSURL URLWithString:URLString];
    feed.author = author;
    return feed;
}

+ (Feed *)feedWithDictionary:(NSDictionary *)dict {
    Feed *feed = [[[Feed alloc] init] autorelease];
    feed.URL = [NSURL URLWithString:[dict objectForKey:@"url"]];
    feed.author = [dict objectForKey:@"author"];
    return feed;
}

- (NSDictionary *)dictionaryRepresentation {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [URL absoluteString], @"url",
            author, @"author",
            nil];

}

- (void)refresh {
    NSURLRequest *URLRequest = [NSURLRequest requestWithURL:URL username:[URL user] password:[URL password]];
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:(id<SMWebRequestDelegate>)[self class] context:nil];
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
            [items addObject:[FeedItem itemWithRSSItemElement:itemXml formatter:formatter]];
    }
    else if ([document.root.name isEqual:@"feed"]) {

        NSArray *itemsXml = [document.root childrenNamed:@"entry"];
        NSDateFormatter *formatter = ATOMDateFormatter();
        
        for (SMXMLElement *itemXml in itemsXml)
            [items addObject:[FeedItem itemWithATOMEntryElement:itemXml formatter:formatter]];

    }
    else NSLog(@"Unknown feed root element: <%@>", document.root.name);
    
    return items;
}

- (void)refreshComplete:(NSArray *)newItems {

    // if we have existing items, merge the new ones in
    if (items) {
        NSMutableArray *merged = [NSMutableArray array];
        
        for (FeedItem *newItem in newItems) {
            int i = (int)[items indexOfObject:newItem];
            if (items != nil && i >= 0)
                [merged addObject:[items objectAtIndex:i]]; // preserve existing item
            else
                [merged addObject:newItem];
        }
        self.items = merged;
        
        // mark as notified any item that was "created" by ourself, because we don't need to be reminded about stuff we did ourself.
        for (FeedItem *item in items)
            if ([item.author isEqual:author])
                item.notified = item.viewed = YES;
    }
    else {
        self.items = newItems;

        // don't notify about the initial fetch, or we'll have a shitload of growl popups
        for (FeedItem *item in items)
            item.notified = item.viewed = YES;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kFeedUpdatedNotification object:self];
}

@end

@implementation FeedItem
@synthesize title, author, content, strippedContent, link, comments, published, updated, notified, viewed;

- (void)dealloc {
    self.title = self.author = self.content = self.strippedContent = nil;
    self.link = self.comments = nil;
    self.published = self.updated = nil;
    [super dealloc];
}

+ (FeedItem *)itemWithRSSItemElement:(SMXMLElement *)element formatter:(NSDateFormatter *)formatter {
    FeedItem *item = [[FeedItem new] autorelease];
    item.title = [element childNamed:@"title"].value;
    item.author = [element childNamed:@"author"].value;
    item.content = [element childNamed:@"description"].value;
    item.strippedContent = [[item.content stringByFlatteningHTML] stringByCondensingSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([element childNamed:@"link"])
        item.link = [NSURL URLWithString:[element childNamed:@"link"].value];
    
    if ([element childNamed:@"comments"])
        item.comments = [NSURL URLWithString:[element childNamed:@"comments"].value];
    
    // basecamp
    if (!item.author && [element childNamed:@"creator"])
        item.author = [element valueWithPath:@"creator"];
    
    item.published = [formatter dateFromString:[element childNamed:@"pubDate"].value];
    item.updated = item.published;
    
    return item;
}

+ (FeedItem *)itemWithATOMEntryElement:(SMXMLElement *)element formatter:(NSDateFormatter *)formatter {
    FeedItem *item = [[FeedItem new] autorelease];
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

- (BOOL)isEqual:(FeedItem *)other {
    if ([other isKindOfClass:[FeedItem class]]) {
        return [link isEqual:other.link] && [updated isEqual:other.updated];
    }
    else return NO;
}

- (NSComparisonResult)compareItemByPublishedDate:(FeedItem *)item {
    return [item.published compare:self.published];
}

@end
