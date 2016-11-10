#import "Feed.h"
#import "Account.h"

#define MAX_FEED_ITEMS 50

NSString *kFeedUpdatedNotification = @"FeedUpdatedNotification";

NSDateFormatter *RSSDateFormatter() {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    return formatter;
}

NSDate *AutoFormatDate(NSString *dateString) {
    static ISO8601DateFormatter *iso8601Formatter = nil; // "2012-01-25T11:12:26Z"
    static NSDateFormatter *rssDateFormatter = nil; // "Sat, 21 Jan 2012 19:22:02 -0500"
    static NSDateFormatter *beanstalkDateFormatter = nil; // "2011/09/12 13:24:05 +0800"
    static NSDateFormatter *pivotalDateFormatter = nil; // "2012/08/21 23:12:03 MSK"
    
    if (!dateString) {
        DDLogCError(@"Couldn't find a date to parse.");
        return nil;
    }
    
    if (!dateString.length) {
        DDLogCError(@"Couldn't parse a date because it was empty.");
        return nil;
    }
    
    // date formatters are NOT threadsafe!
    @synchronized ([Feed class]) {
        if (!iso8601Formatter) iso8601Formatter = [ISO8601DateFormatter new];
        if (!rssDateFormatter) rssDateFormatter = RSSDateFormatter();
        
        if (!beanstalkDateFormatter) {
            beanstalkDateFormatter = [[NSDateFormatter alloc] init];
            [beanstalkDateFormatter setDateFormat:@"yyyy'/'MM'/'dd HH':'mm':'ss ZZZ"];
        }

        if (!pivotalDateFormatter) {
            pivotalDateFormatter = [[NSDateFormatter alloc] init];
            [pivotalDateFormatter setDateFormat:@"yyyy'/'MM'/'dd HH':'mm':'ss z"];
        }
        
        NSDate *date = nil;
        
        // if the string contains forward-slashes and no uppercase characters, it's beanstalk.
        if ([dateString containsString:@"/"] && ![dateString containsCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]])
            date = [beanstalkDateFormatter dateFromString:dateString];
        
        // if the string contains forward-slashes and uppercase characters, it's pivotal.
        if ([dateString containsString:@"/"] && [dateString containsCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]]) {
            // so, according to http://www.openradar.me/9944011, Apple updated the ICU library which NSDateFormatter
            // depends on, some time during the Lion/iOS 5 era. and it no longer handles most 3-letter timezones
            // like "MSK" in particular (Moscow Time) because they're ambiguous whatever.
            // which means we get to do this awesome jazz where we try and swap out the 3-letter code in
            // this date format with something else.
            NSString *threeLetterZone = [dateString componentsSeparatedByString:@" "].lastObject;
            
            NSTimeZone *timeZone = [NSTimeZone timeZoneWithAbbreviation:threeLetterZone];
            if (timeZone) {
                NSString *gmtTime = [dateString stringByReplacingOccurrencesOfString:threeLetterZone withString:@"GMT"];
                date = [[pivotalDateFormatter dateFromString:gmtTime] dateByAddingTimeInterval:-timeZone.secondsFromGMT];
            }
        }
        
        // try ISO 8601 next
        if (date.timeIntervalSinceReferenceDate < 1 && [dateString containsString:@"-"] && [dateString containsString:@"T"])
            date = [iso8601Formatter dateFromString:dateString];

        // no luck? try RSS
        if (date.timeIntervalSinceReferenceDate < 1 && [dateString containsString:@","])
            date = [rssDateFormatter dateFromString:dateString];
        
        // no luck? throw the kitchen sink at it
        if (date.timeIntervalSinceReferenceDate < 1)
            date = [NSDate dateFromInternetDateTimeString:dateString formatHint:DateFormatHintNone];
        
        if (date.timeIntervalSinceReferenceDate > 1) {
            //DDLogCInfo(@"Parsed date from %@ to %@ (%@)", dateString, date, date.timeAgo);
            return date;
        }
        else {
            DDLogCError(@"Couldn't parse date %@", dateString);
            return nil;
        }
    }
}

@interface Feed ()
@property (nonatomic, strong) SMWebRequest *request;
@end

@implementation Feed

- (void)dealloc {
    self.account = nil;
}

- (void)setRequest:(SMWebRequest *)request_ {
    [_request removeTarget:self];
    _request = request_;
}

+ (Feed *)feedWithURLString:(NSString *)URLString title:(NSString *)title account:(Account *)account {
    return [self feedWithURLString:URLString title:title author:nil account:account];
}

+ (Feed *)feedWithURLString:(NSString *)URLString title:(NSString *)title author:(NSString *)author account:(Account *)account {
    Feed *feed = [[Feed alloc] init];
    feed.URL = [NSURL URLWithString:URLString];
    feed.title = title;
    feed.author = author;
    feed.account = account;
    return feed;
}

+ (Feed *)feedWithDictionary:(NSDictionary *)dict account:(Account *)account {
    Feed *feed = [[Feed alloc] init];
    feed.URL = [NSURL URLWithString:dict[@"url"]];
    feed.title = dict[@"title"];
    feed.author = dict[@"author"];
    feed.requestHeaders = dict[@"requestHeaders"];
    feed.incremental = [dict[@"incremental"] boolValue];
    feed.requiresBasicAuth = [dict[@"requiresBasicAuth"] boolValue];
    feed.requiresOAuth2Token = [dict[@"requiresOAuth2Token"] boolValue];
    feed.disabled = [dict[@"disabled"] boolValue];
    feed.account = account;
    return feed;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"url"] = [self.URL absoluteString];
    if (self.title) dict[@"title"] = self.title;
    if (self.author) dict[@"author"] = self.author;
    if (self.requestHeaders) dict[@"requestHeaders"] = self.requestHeaders;
    dict[@"incremental"] = @(self.incremental);
    dict[@"requiresBasicAuth"] = @(self.requiresBasicAuth);
    dict[@"requiresOAuth2Token"] = @(self.requiresOAuth2Token);
    dict[@"disabled"] = @(self.disabled);
    return dict;
}

- (BOOL)isEqual:(Feed *)other {
    if ([other isKindOfClass:[Feed class]])
        return [self.URL isEqual:other.URL] && [self.title isEqual:other.title] && ((!self.author && !other.author) || [self.author isEqual:other.author]) &&
            self.requiresBasicAuth == other.requiresBasicAuth && self.requiresOAuth2Token == other.requiresOAuth2Token && self.incremental == other.incremental;
    else
        return NO;
}

- (void)refresh { [self refreshWithURL:self.URL]; }

- (void)refreshWithURL:(NSURL *)refreshURL {
    NSMutableURLRequest *URLRequest;
    
    NSString *domain = self.account.domain, *username = self.account.username, *password = self.account.findPassword;
    
    if (self.requiresBasicAuth) // this feed requires the secure user/pass we stored in the keychain
        URLRequest = [NSMutableURLRequest requestWithURL:refreshURL username:username password:password];
    else if (self.requiresOAuth2Token) // like basecamp next
        URLRequest = [NSMutableURLRequest requestWithURL:refreshURL OAuth2Token:[OAuth2Token tokenWithStringRepresentation:password]];
    else if ([refreshURL user] && [refreshURL password]) // maybe the user/pass is built into the URL already? (this is the case for services like Basecamp that use "tokens" built into the URL)
        URLRequest = [NSMutableURLRequest requestWithURL:refreshURL username:[refreshURL user] password:[refreshURL password]];
    else // just a normal URL.
        URLRequest = [NSMutableURLRequest requestWithURL:refreshURL];
    
    // add any additional request headers
    for (NSString *field in self.requestHeaders)
        [URLRequest setValue:(self.requestHeaders)[field] forHTTPHeaderField:field];
    
    URLRequest.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData; // goes without saying that we only care about fresh data for Feeds
    
    // build a useful context of extra data for custom feed processors like Trello and Beanstalk. Since those processors may need to fetch
    // additional data from their respective APIs, they may need the account usernamd and password, if applicable.
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    context[@"accountClass"] = [self.account class];
    if (domain) context[@"domain"] = domain;
    if (username) context[@"username"] = username;
    if (password) context[@"password"] = password;
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:(id<SMWebRequestDelegate>)[self class] context:context];
    [self.request addTarget:self action:@selector(refreshComplete:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(refreshError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

// This method is called on a background thread. Don't touch your instance members!
+ (id)webRequest:(SMWebRequest *)webRequest resultObjectForData:(NSData *)data context:(NSDictionary *)context {

    Class accountClass = context[@"accountClass"];
    NSString *domain = context[@"domain"];
    NSString *username = context[@"username"];
    NSString *password = context[@"password"];
    
    if ([(id)accountClass respondsToSelector:@selector(itemsForRequest:data:domain:username:password:)])
        return [accountClass itemsForRequest:webRequest data:data domain:domain username:username password:password];
    
    NSError *error = nil;
    NSArray *items = [self feedItemsWithData:data discoveredTitle:NULL error:&error];
    
    if (error) {
        DDLogError(@"Error parsing XML feed result for %@ - %@", webRequest.request.URL, error);
        return nil;
    }

    return items;
}

+ (NSArray *)feedItemsWithData:(NSData *)data discoveredTitle:(NSString **)title error:(NSError **)error {
    
    // try parsing the XML first
    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:error];
    if ((*error)) return nil;

    NSMutableArray *items = [NSMutableArray array];
    
    // are we speaking RSS or ATOM here?
    if ([document.root.name isEqual:@"rss"]) {
    
        if (title) *title = [document.root valueWithPath:@"channel.title"];
        
        NSArray *itemsXml = [[document.root childNamed:@"channel"] childrenNamed:@"item"];
        
        for (SMXMLElement *itemXml in itemsXml)
            [items addObject:[FeedItem itemWithRSSItemElement:itemXml]];
    }
    else if ([document.root.name isEqual:@"feed"]) {
        
        if (title) *title = [document.root valueWithPath:@"title"];
        
        NSArray *itemsXml = [document.root childrenNamed:@"entry"];
        
        for (SMXMLElement *itemXml in itemsXml)
            [items addObject:[FeedItem itemWithATOMEntryElement:itemXml]];
    }
    else if ([document.root.name isEqual:@"RDF"]) {
        
        if (title) *title = [document.root valueWithPath:@"channel.title"];
        
        NSArray *itemsXml = [document.root childrenNamed:@"item"];
        
        for (SMXMLElement *itemXml in itemsXml)
            [items addObject:[FeedItem itemWithRSSItemElement:itemXml]];
    }
    else {
        NSString *message = [NSString stringWithFormat:@"Unknown feed root element: <%@>", document.root.name];
        if (error) *error = [NSError errorWithDomain:@"Feed" code:0 userInfo:
                  @{NSLocalizedDescriptionKey: message}];
        return nil;
    }
    
    if (error) *error = nil;
    return items;
}


- (void)refreshComplete:(NSArray *)newItems {

    if (!newItems) {
        // problem refreshing the feed!
        // TODO: something
        return;
    }
    
    // if we have existing items, merge the new ones in
    if (self.items) {
        NSMutableArray *merged = [NSMutableArray array];
        
        if (self.incremental) {

            // populate the final set, newest item to oldest.
            
            for (FeedItem *newItem in newItems) {
                DDLogInfo(@"NEW ITEM FOR FEED %@: %@", self.URL, newItem);
                [merged addObject:newItem];
            }

            for (FeedItem *oldItem in self.items) {
                int i = (int)[newItems indexOfObject:oldItem]; // have we updated this item?
                if (i < 0)
                    [merged addObject:oldItem];
            }
            
            // necessary for incremental feeds where we keep collecting items
            while (merged.count > MAX_FEED_ITEMS) [merged removeLastObject];
        }
        else {
            for (FeedItem *newItem in newItems) {
                int i = (int)[self.items indexOfObject:newItem];
                if (i >= 0)
                    [merged addObject:(self.items)[i]]; // preserve existing item
                else {
                    DDLogInfo(@"NEW ITEM FOR FEED %@: %@", self.URL, newItem);
                    [merged addObject:newItem];
                }
            }
        }

        self.items = merged;
        
        // mark as notified any item that was "created" by ourself, because we don't need to be reminded about stuff we did ourself.
        for (FeedItem *item in self.items) {
            if ([(item.authorIdentifier ?: item.author) isEqual:self.author]) // prefer authorIdentifier if present
                item.authoredByMe = YES;
            
            if (item.authoredByMe)
                item.notified = item.viewed = YES;
        }
    }
    else {
        DDLogInfo(@"ALL NEW ITEMS FOR FEED %@", self.URL);
        self.items = newItems;

        // don't notify about the initial fetch, or we'll have a shitload of growl popups
        for (FeedItem *item in self.items)
            item.notified = item.viewed = YES;
    }
    
    // link them back to us
    for (FeedItem *item in self.items)
        item.feed = self;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kFeedUpdatedNotification object:self];
}

- (void)refreshError:(NSError *)error {
    DDLogError(@"Error: %@", error);
}

@end

@implementation FeedItem

- (void)dealloc {
    self.feed = nil;
}

+ (FeedItem *)itemWithRSSItemElement:(SMXMLElement *)element {
    FeedItem *item = [FeedItem new];
    item.title = [element childNamed:@"title"].value;
    item.content = [element childNamed:@"description"].value;

    SMXMLElement *author = [element childNamed:@"author"];
    
    if ([author childNamed:@"name"])
        item.author = [author valueWithPath:@"name"];
    else {
        item.author = author.value;
        
        // with RSS 2.0, author must be an email address, but you can have the full name in parens.
        // we'll pull that out if it's in there.
        NSString *authorName = [item.author stringByMatching:@"[^@]+@[^@\\(]+\\(([^\\)]+)\\)" capture:1];
        if (authorName.length) item.author = authorName;
    }

    SMXMLElement *guid = [element childNamed:@"guid"]; // RSS 2.0
    SMXMLElement *link = [element childNamed:@"link"]; // RSS 1.0?
    
    if (guid && guid.value && NSEqualStrings([guid attributeNamed:@"isPermaLink"],@"true"))
        item.link = [NSURL URLWithString:guid.value];
    else if (link && link.value)
        item.link = [NSURL URLWithString:link.value];
    else if (link && [link attributeNamed:@"href"])
        item.link = [NSURL URLWithString:[link attributeNamed:@"href"]];
    
    if ([element childNamed:@"comments"])
        item.comments = [NSURL URLWithString:[element childNamed:@"comments"].value];
    
    // for <dc:creator>, some "Dublic Core" nonsense
    if (!item.author.length && [element childNamed:@"creator"])
        item.author = [element valueWithPath:@"creator"];

    NSString *published = [element childNamed:@"pubDate"].value;
    
    // for <dc:date>, some "Dublin Core" nonsense
    if (!published && [element childNamed:@"date"])
        published = [element valueWithPath:@"date"];
    
    item.rawDate = published;
    item.published = AutoFormatDate(published);
    item.updated = item.published;
    return item;
}

+ (FeedItem *)itemWithATOMEntryElement:(SMXMLElement *)element {
    FeedItem *item = [FeedItem new];
    item.title = [element childNamed:@"title"].value;
    item.author = [element valueWithPath:@"author.name"];
    item.content = [element childNamed:@"content"].value;
    
    // in some cases (Wikipedia) we may receive a <summary> instead of a <content> node
    if (!item.content && [element childNamed:@"summary"])
        item.content = [element childNamed:@"summary"].value;
    
    NSString *linkHref = [[element childNamed:@"link"] attributeNamed:@"href"];
    
    if (linkHref.length)
        item.link = [NSURL URLWithString:linkHref];
    
    NSString *published = [element childNamed:@"published"].value;
    NSString *updated = [element childNamed:@"updated"].value;
    
    // in some cases (Wikipedia), ATOM entries may have an <updated> date and NOT a <published> date.
    // let's handle those cases.
    if (updated && !published)
        published = updated;
    
    item.rawDate = published;
    item.published = AutoFormatDate(published);
    item.updated = AutoFormatDate(updated);
    return item;
}

- (BOOL)isEqual:(FeedItem *)other {
    if ([other isKindOfClass:[FeedItem class]]) {
        // can we compare by some notion of a unique identifier?
        if (self.identifier && other.identifier) return NSEqualStrings(self.identifier, other.identifier);
        
        // ok, compare by content.
        // order is important - content comes last because it's expensive to compare but typically it'll short-circuit before getting there.
        return NSEqualObjects(self.link, other.link) && NSEqualStrings(self.title, other.title) && NSEqualStrings(self.author, other.author) && NSEqualStrings(self.content, other.content);
         // && [updated isEqual:other.updated]; // ignore updated, it creates too many false positives
    }
    else return NO;
}

- (NSUInteger)hash {
    // http://stackoverflow.com/questions/254281/best-practices-for-overriding-isequal-and-hash
    NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + [self.identifier hash];
    result = prime * result + [self.link hash];
    result = prime * result + [self.title hash];
    result = prime * result + [self.author hash];
    result = prime * result + [self.content hash];
    return result;
}

- (NSString *)authorAndTitle {
    if (self.author && self.title && ![self.title beginsWithString:self.author])
        return [NSString stringWithFormat:@"%@: %@",self.author,self.title];
    else if (self.title)
        return self.title;
    else if (self.author)
        return self.author;
    else
        return @"";
}

- (NSString *)description {
    return [NSString stringWithFormat:@"FeedItem (%@ - %@)\n)",
            self.published,[self.authorAndTitle.stringByDecodingCharacterEntities truncatedAfterIndex:25], nil];
}

- (NSComparisonResult)compareItemByPublishedDate:(FeedItem *)item {
    // assume itmes without dates are really old
    return [(item.published ?: [NSDate distantPast]) compare:(self.published ?: [NSDate distantPast])];
}

- (NSAttributedString *)attributedStringHighlighted:(BOOL)highlighted {

    NSString *decodedTitle = [(self.title.length ? self.title : self.content) stringByFlatteningHTML]; // fallback to content if no title
    NSString *decodedAuthor = [self.author stringByFlatteningHTML];

    NSDictionary *titleAtts = @{NSFontAttributeName: [NSFont systemFontOfSize:13.0f]};

    if (decodedAuthor.length) {
        NSString *authorSpace = [decodedAuthor stringByAppendingString:@" "];
        
        // if the title begins with the author, it's redundant; trim it out
        if ([decodedTitle rangeOfString:authorSpace].location == 0)
            decodedTitle = [decodedTitle substringFromIndex:authorSpace.length];
        
        decodedAuthor = [decodedAuthor truncatedWithString:@"" afterIndex:15];
        decodedTitle = [decodedTitle truncatedAfterIndex:40-decodedAuthor.length];
        
        NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ %@",decodedAuthor,decodedTitle]];
        
        NSColor *authorColor = highlighted ? [NSColor selectedMenuItemTextColor] : [NSColor disabledControlTextColor]; 
        
        NSDictionary *authorAtts = @{NSFontAttributeName: [NSFont systemFontOfSize:13.0f],
                                    NSForegroundColorAttributeName: authorColor};
                
        NSRange authorRange = NSMakeRange(0, decodedAuthor.length);
        NSRange titleRange = NSMakeRange(decodedAuthor.length+1, decodedTitle.length);
        
        [attributed addAttributes:authorAtts range:authorRange];
        [attributed addAttributes:titleAtts range:titleRange];
        return attributed;
    }
    else {
        decodedTitle = [decodedTitle truncatedAfterIndex:40];
        NSMutableAttributedString *attributed = [[NSMutableAttributedString alloc] initWithString:decodedTitle];
        [attributed addAttributes:titleAtts range:NSMakeRange(0, decodedTitle.length)];
        return attributed;
    }
}

@end
