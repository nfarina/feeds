#import "Feed.h"
#import "Account.h"

NSString *kFeedUpdatedNotification = @"FeedUpdatedNotification";

NSDateFormatter *RSSDateFormatter() {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    return formatter;
}

NSDate *AutoFormatDate(NSString *dateString) {
    static ISO8601DateFormatter *iso8601Formatter = nil; // "2012-01-25T11:12:26Z"
    static NSDateFormatter *rssDateFormatter = nil; // "Sat, 21 Jan 2012 19:22:02 -0500"
    static NSDateFormatter *beanstalkDateFormatter = nil; // "2011/09/12 13:24:05 +0800"
    
    // date formatters are NOT threadsafe!
    @synchronized ([Feed class]) {
        if (!iso8601Formatter) iso8601Formatter = [ISO8601DateFormatter new];
        if (!rssDateFormatter) rssDateFormatter = [RSSDateFormatter() retain];
        
        if (!beanstalkDateFormatter) {
            beanstalkDateFormatter = [[NSDateFormatter alloc] init];
            [beanstalkDateFormatter setDateFormat:@"yyyy'/'MM'/'dd HH':'mm':'ss ZZZ"];
        }
        
        NSDate *date = nil;
        
        // if the string contains forward-slashes, it's beanstalk.
        if ([dateString containsString:@"/"])
            date = [beanstalkDateFormatter dateFromString:dateString];
        
        // try ISO 8601 next
        if (date.timeIntervalSinceReferenceDate < 1)
            date = [iso8601Formatter dateFromString:dateString];

        // no luck? try RSS
        if (date.timeIntervalSinceReferenceDate < 1)
            date = [rssDateFormatter dateFromString:dateString];
        
        if (date.timeIntervalSinceReferenceDate > 1)
            return date;
        else {
            NSLog(@"Couldn't parse date %@", dateString);
            return nil;
        }
    }
}

//NSDateFormatter *ATOMDateFormatter() {
//    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
//    [formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
//    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
//    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
//    return formatter;
//}
//
//NSDateFormatter *ATOMDateFormatterWithTimeZone() {
//    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
//    [formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
//    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZ"];
//    return formatter;
//}

@interface Feed ()
@property (nonatomic, retain) SMWebRequest *request;
@end

@implementation Feed
@synthesize URL, title, author, items, request, disabled, account, requiresBasicAuth;

- (void)dealloc {
    self.URL = nil;
    self.title = nil;
    self.author = nil;
    self.items = nil;
    self.request = nil;
    self.account = nil;
    [super dealloc];
}

+ (Feed *)feedWithURLString:(NSString *)URLString title:(NSString *)title account:(Account *)account {
    return [self feedWithURLString:URLString title:title author:nil account:account];
}

+ (Feed *)feedWithURLString:(NSString *)URLString title:(NSString *)title author:(NSString *)author account:(Account *)account {
    Feed *feed = [[[Feed alloc] init] autorelease];
    feed.URL = [NSURL URLWithString:URLString];
    feed.title = title;
    feed.author = author;
    feed.account = account;
    return feed;
}

+ (Feed *)feedWithDictionary:(NSDictionary *)dict account:(Account *)account {
    Feed *feed = [[[Feed alloc] init] autorelease];
    feed.URL = [NSURL URLWithString:[dict objectForKey:@"url"]];
    feed.title = [dict objectForKey:@"title"];
    feed.author = [dict objectForKey:@"author"];
    feed.disabled = [[dict objectForKey:@"disabled"] boolValue];
    feed.requiresBasicAuth = [[dict objectForKey:@"requiresBasicAuth"] boolValue];
    feed.account = account;
    return feed;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[URL absoluteString] forKey:@"url"];
    if (title) [dict setObject:title forKey:@"title"];
    if (author) [dict setObject:author forKey:@"author"];
    [dict setObject:[NSNumber numberWithBool:disabled] forKey:@"disabled"];
    [dict setObject:[NSNumber numberWithBool:requiresBasicAuth] forKey:@"requiresBasicAuth"];
    return dict;
}

- (BOOL)isEqual:(Feed *)other {
    if ([other isKindOfClass:[Feed class]])
        return [URL isEqual:other.URL] && [title isEqual:other.title] && ((!author && !other.author) || [author isEqual:other.author]) && requiresBasicAuth == other.requiresBasicAuth;
    else
        return NO;
}

- (void)refresh {
    NSMutableURLRequest *URLRequest;
    
    NSString *domain = account.domain, *username = account.username, *password = account.findPassword;
    
    if (requiresBasicAuth) // this feed requires the secure user/pass we stored in the keychain
        URLRequest = (NSMutableURLRequest *)[NSMutableURLRequest requestWithURL:URL username:username password:password];
    else if ([URL user] && [URL password]) // maybe the user/pass is built into the URL already? (this is the case for services like Basecamp that use "tokens" built into the URL)
        URLRequest = (NSMutableURLRequest *)[NSMutableURLRequest requestWithURL:URL username:[URL user] password:[URL password]];
    else // just a normal URL.
        URLRequest = (NSMutableURLRequest *)[NSMutableURLRequest requestWithURL:URL];
    
    URLRequest.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData; // goes without saying that we only care about fresh data for Feeds
    
    // build a useful context of extra data for custom feed processors like Trello and Beanstalk. Since those processors may need to fetch
    // additional data from their respective APIs, they may need the account usernamd and password, if applicable.
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    if (domain) [context setObject:domain forKey:@"domain"];
    if (username) [context setObject:username forKey:@"username"];
    if (password) [context setObject:password forKey:@"password"];
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:(id<SMWebRequestDelegate>)[self class] context:context];
    [request addTarget:self action:@selector(refreshComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(refreshError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

// This method is called on a background thread. Don't touch your instance members!
+ (id)webRequest:(SMWebRequest *)webRequest resultObjectForData:(NSData *)data context:(NSDictionary *)context {

    NSString *domain = [context objectForKey:@"domain"];
    NSString *username = [context objectForKey:@"username"];
    NSString *password = [context objectForKey:@"password"];
    
    NSArray *customItems = [Account itemsForRequest:webRequest data:data domain:domain username:username password:password];
    if (customItems) return customItems;
    
    NSError *error = nil;
    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:&error];
    NSMutableArray *items = [NSMutableArray array];
    
    if (error) {
        NSLog(@"Error parsing XML feed result for %@ - %@", webRequest.request.URL, error);
        return nil;
    }

    // are we speaking RSS or ATOM here?
    if ([document.root.name isEqual:@"rss"]) {

        NSArray *itemsXml = [[document.root childNamed:@"channel"] childrenNamed:@"item"];
        
        for (SMXMLElement *itemXml in itemsXml)
            [items addObject:[FeedItem itemWithRSSItemElement:itemXml]];
    }
    else if ([document.root.name isEqual:@"feed"]) {

        NSArray *itemsXml = [document.root childrenNamed:@"entry"];
        
        for (SMXMLElement *itemXml in itemsXml)
            [items addObject:[FeedItem itemWithATOMEntryElement:itemXml]];

    }
    else {
        NSLog(@"Unknown feed root element: <%@>", document.root.name);
        return nil;
    }
    
    return items;
}

- (void)refreshComplete:(NSArray *)newItems {

    if (!newItems) {
        // problem refreshing the feed!
        // TODO: something
        return;
    }
    
    // if we have existing items, merge the new ones in
    if (items) {
        NSMutableArray *merged = [NSMutableArray array];
        
        for (FeedItem *newItem in newItems) {
            int i = (int)[items indexOfObject:newItem];
            if (items != nil && i >= 0)
                [merged addObject:[items objectAtIndex:i]]; // preserve existing item
            else {
                NSLog(@"NEW ITEM FOR FEED %@: %@", URL, newItem);
                [merged addObject:newItem];
            }
        }
        self.items = merged;
        
        // mark as notified any item that was "created" by ourself, because we don't need to be reminded about stuff we did ourself.
        for (FeedItem *item in items)
            if ([(item.authorIdentifier ?: item.author) isEqual:author]) // prefer authorIdentifier if present
                item.notified = item.viewed = YES;
    }
    else {
        NSLog(@"ALL NEW ITEMS FOR FEED %@", URL);
        self.items = newItems;

        // don't notify about the initial fetch, or we'll have a shitload of growl popups
        for (FeedItem *item in items)
            item.notified = item.viewed = YES;
    }
    
    // link them back to us
    for (FeedItem *item in items)
        item.feed = self;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kFeedUpdatedNotification object:self];
}

- (void)refreshError:(NSError *)error {
    NSLog(@"Error: %@", error);
}

@end

@implementation FeedItem
@synthesize title, author, authorIdentifier, project, content, link, comments, published, updated, notified, viewed, feed, rawDate;

- (void)dealloc {
    self.title = self.author = self.content = self.rawDate = nil;
    self.link = self.comments = nil;
    self.published = self.updated = nil;
    self.feed = nil;
    [super dealloc];
}

+ (FeedItem *)itemWithRSSItemElement:(SMXMLElement *)element {
    FeedItem *item = [[FeedItem new] autorelease];
    item.title = [element childNamed:@"title"].value;
    item.author = [element childNamed:@"author"].value;
    item.content = [element childNamed:@"description"].value;
    
    if ([element childNamed:@"link"])
        item.link = [NSURL URLWithString:[element childNamed:@"link"].value];
    
    if ([element childNamed:@"comments"])
        item.comments = [NSURL URLWithString:[element childNamed:@"comments"].value];
    
    // basecamp
    if (!item.author && [element childNamed:@"creator"])
        item.author = [element valueWithPath:@"creator"];
    
    NSString *published = [element childNamed:@"pubDate"].value;
    
    item.rawDate = published;
    item.published = AutoFormatDate(published);
    item.updated = item.published;
    return item;
}

+ (FeedItem *)itemWithATOMEntryElement:(SMXMLElement *)element {
    FeedItem *item = [[FeedItem new] autorelease];
    item.title = [element childNamed:@"title"].value;
    item.author = [element valueWithPath:@"author.name"];
    item.content = [element childNamed:@"content"].value;
    
    NSString *linkHref = [[element childNamed:@"link"] attributeNamed:@"href"];
    
    if (linkHref.length)
        item.link = [NSURL URLWithString:linkHref];
    
    NSString *published = [element childNamed:@"published"].value;
    NSString *updated = [element childNamed:@"updated"].value;
    
    item.rawDate = published;
    item.published = AutoFormatDate(published);
    item.updated = AutoFormatDate(updated);
    return item;
}

- (BOOL)isEqual:(FeedItem *)other {
    if ([other isKindOfClass:[FeedItem class]]) {
        // order is important - content comes last because it's expensive to compare but typically it'll short-circuit before getting there.
        return NSEqualObjects(link, other.link) && NSEqualStrings(title, other.title) && NSEqualStrings(author, other.author) && NSEqualStrings(content, other.content);
         // && [updated isEqual:other.updated]; // ignore updated, it creates too many false positives
    }
    else return NO;
}

- (NSString *)authorAndTitle {
    return author && ![title beginsWithString:author] ? [NSString stringWithFormat:@"%@: %@",author,title] : title;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"FeedItem (%@ - %@)\n)",
            published,[self.authorAndTitle.stringByDecodingCharacterEntities truncatedAfterIndex:25], nil];
}

- (NSComparisonResult)compareItemByPublishedDate:(FeedItem *)item {
    return [item.published compare:self.published];
}

- (NSAttributedString *)attributedStringHighlighted:(BOOL)highlighted {

    NSString *decodedTitle = [(title.length ? title : content) stringByDecodingCharacterEntities]; // fallback to content if no title
    NSString *decodedAuthor = [author stringByDecodingCharacterEntities];

    NSDictionary *titleAtts = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSFont systemFontOfSize:13.0f],NSFontAttributeName,nil];

    if (decodedAuthor.length) {
        NSString *authorSpace = [decodedAuthor stringByAppendingString:@" "];
        
        if ([decodedTitle rangeOfString:authorSpace].location == 0)
            decodedTitle = [decodedTitle substringFromIndex:authorSpace.length];
        
        decodedTitle = [decodedTitle truncatedAfterIndex:40-decodedAuthor.length];
        
        NSMutableAttributedString *attributed = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ %@",decodedAuthor,decodedTitle]] autorelease];
        
        NSColor *authorColor = highlighted ? [NSColor selectedMenuItemTextColor] : [NSColor disabledControlTextColor]; 
        
        NSDictionary *authorAtts = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:13.0f],NSFontAttributeName,
                                    authorColor,NSForegroundColorAttributeName,nil];
                
        NSRange authorRange = NSMakeRange(0, decodedAuthor.length);
        NSRange titleRange = NSMakeRange(decodedAuthor.length+1, decodedTitle.length);
        
        [attributed addAttributes:authorAtts range:authorRange];
        [attributed addAttributes:titleAtts range:titleRange];
        return attributed;
    }
    else {
        NSMutableAttributedString *attributed = [[[NSMutableAttributedString alloc] initWithString:decodedTitle] autorelease];
        [attributed addAttributes:titleAtts range:NSMakeRange(0, decodedTitle.length)];
        return attributed;
    }
}

@end
