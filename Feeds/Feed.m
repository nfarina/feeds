#import "Feed.h"
#import "Account.h"

#define MAX_FEED_ITEMS 50

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
        if (!rssDateFormatter) rssDateFormatter = [RSSDateFormatter() retain];
        
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
@property (nonatomic, retain) SMWebRequest *request;
@end

@implementation Feed
@synthesize URL, title, author, items, request, disabled, account, requestHeaders, requiresBasicAuth, requiresOAuth2Token, incremental;

- (void)dealloc {
    self.URL = nil;
    self.title = nil;
    self.author = nil;
    self.requestHeaders = nil;
    self.items = nil;
    self.request = nil;
    self.account = nil;
    [super dealloc];
}

- (void)setRequest:(SMWebRequest *)request_ {
    [request removeTarget:self];
    [request release], request = [request_ retain];
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
    feed.requestHeaders = [dict objectForKey:@"requestHeaders"];
    feed.incremental = [[dict objectForKey:@"incremental"] boolValue];
    feed.requiresBasicAuth = [[dict objectForKey:@"requiresBasicAuth"] boolValue];
    feed.requiresOAuth2Token = [[dict objectForKey:@"requiresOAuth2Token"] boolValue];
    feed.disabled = [[dict objectForKey:@"disabled"] boolValue];
    feed.account = account;
    return feed;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[URL absoluteString] forKey:@"url"];
    if (title) [dict setObject:title forKey:@"title"];
    if (author) [dict setObject:author forKey:@"author"];
    if (requestHeaders) [dict setObject:requestHeaders forKey:@"requestHeaders"];
    [dict setObject:[NSNumber numberWithBool:incremental] forKey:@"incremental"];
    [dict setObject:[NSNumber numberWithBool:requiresBasicAuth] forKey:@"requiresBasicAuth"];
    [dict setObject:[NSNumber numberWithBool:requiresOAuth2Token] forKey:@"requiresOAuth2Token"];
    [dict setObject:[NSNumber numberWithBool:disabled] forKey:@"disabled"];
    return dict;
}

- (BOOL)isEqual:(Feed *)other {
    if ([other isKindOfClass:[Feed class]])
        return [URL isEqual:other.URL] && [title isEqual:other.title] && ((!author && !other.author) || [author isEqual:other.author]) && 
            requiresBasicAuth == other.requiresBasicAuth && requiresOAuth2Token == other.requiresOAuth2Token && incremental == other.incremental;
    else
        return NO;
}

- (void)refresh { [self refreshWithURL:URL]; }

- (void)refreshWithURL:(NSURL *)refreshURL {
    NSMutableURLRequest *URLRequest;
    
    NSString *domain = account.domain, *username = account.username, *password = account.findPassword;
    
    if (requiresBasicAuth) // this feed requires the secure user/pass we stored in the keychain
        URLRequest = [NSMutableURLRequest requestWithURL:refreshURL username:username password:password];
    else if (requiresOAuth2Token) // like basecamp next
        URLRequest = [NSMutableURLRequest requestWithURL:refreshURL OAuth2Token:[OAuth2Token tokenWithStringRepresentation:password]];
    else if ([refreshURL user] && [refreshURL password]) // maybe the user/pass is built into the URL already? (this is the case for services like Basecamp that use "tokens" built into the URL)
        URLRequest = [NSMutableURLRequest requestWithURL:refreshURL username:[refreshURL user] password:[refreshURL password]];
    else // just a normal URL.
        URLRequest = [NSMutableURLRequest requestWithURL:refreshURL];
    
    // add any additional request headers
    for (NSString *field in requestHeaders)
        [URLRequest setValue:[requestHeaders objectForKey:field] forHTTPHeaderField:field];
    
    URLRequest.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData; // goes without saying that we only care about fresh data for Feeds
    
    // build a useful context of extra data for custom feed processors like Trello and Beanstalk. Since those processors may need to fetch
    // additional data from their respective APIs, they may need the account usernamd and password, if applicable.
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    [context setObject:[self.account class] forKey:@"accountClass"];
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

    Class accountClass = [context objectForKey:@"accountClass"];
    NSString *domain = [context objectForKey:@"domain"];
    NSString *username = [context objectForKey:@"username"];
    NSString *password = [context objectForKey:@"password"];
    
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
    else {
        NSString *message = [NSString stringWithFormat:@"Unknown feed root element: <%@>", document.root.name];
        if (error) *error = [NSError errorWithDomain:@"Feed" code:0 userInfo:
                  [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
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
    if (items) {
        NSMutableArray *merged = [NSMutableArray array];
        
        if (incremental) {

            // populate the final set, newest item to oldest.
            
            for (FeedItem *newItem in newItems) {
                DDLogInfo(@"NEW ITEM FOR FEED %@: %@", URL, newItem);
                [merged addObject:newItem];
            }

            for (FeedItem *oldItem in items) {
                int i = (int)[newItems indexOfObject:oldItem]; // have we updated this item?
                if (i < 0)
                    [merged addObject:oldItem];
            }
            
            // necessary for incremental feeds where we keep collecting items
            while (merged.count > MAX_FEED_ITEMS) [merged removeLastObject];
        }
        else {
            for (FeedItem *newItem in newItems) {
                int i = (int)[items indexOfObject:newItem];
                if (i >= 0)
                    [merged addObject:[items objectAtIndex:i]]; // preserve existing item
                else {
                    DDLogInfo(@"NEW ITEM FOR FEED %@: %@", URL, newItem);
                    [merged addObject:newItem];
                }
            }
        }

        self.items = merged;
        
        // mark as notified any item that was "created" by ourself, because we don't need to be reminded about stuff we did ourself.
        for (FeedItem *item in items) {
            if ([(item.authorIdentifier ?: item.author) isEqual:author]) // prefer authorIdentifier if present
                item.authoredByMe = YES;
            
            if (item.authoredByMe)
                item.notified = item.viewed = YES;
        }
    }
    else {
        DDLogInfo(@"ALL NEW ITEMS FOR FEED %@", URL);
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
    DDLogError(@"Error: %@", error);
}

@end

@implementation FeedItem
@synthesize identifier, title, author, authorIdentifier, project, content, link, comments, published, updated, notified, viewed, feed, rawDate, authoredByMe;

- (void)dealloc {
    self.identifier = self.title = self.author = self.content = self.rawDate = nil;
    self.link = self.comments = nil;
    self.published = self.updated = nil;
    self.feed = nil;
    [super dealloc];
}

+ (FeedItem *)itemWithRSSItemElement:(SMXMLElement *)element {
    FeedItem *item = [[FeedItem new] autorelease];
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
    FeedItem *item = [[FeedItem new] autorelease];
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
        if (identifier && other.identifier) return NSEqualStrings(identifier, other.identifier);
        
        // ok, compare by content.
        // order is important - content comes last because it's expensive to compare but typically it'll short-circuit before getting there.
        return NSEqualObjects(link, other.link) && NSEqualStrings(title, other.title) && NSEqualStrings(author, other.author) && NSEqualStrings(content, other.content);
         // && [updated isEqual:other.updated]; // ignore updated, it creates too many false positives
    }
    else return NO;
}

- (NSString *)authorAndTitle {
    if (author && title && ![title beginsWithString:author])
        return [NSString stringWithFormat:@"%@: %@",author,title];
    else if (title)
        return title;
    else if (author)
        return author;
    else
        return @"";
}

- (NSString *)description {
    return [NSString stringWithFormat:@"FeedItem (%@ - %@)\n)",
            published,[self.authorAndTitle.stringByDecodingCharacterEntities truncatedAfterIndex:25], nil];
}

- (NSComparisonResult)compareItemByPublishedDate:(FeedItem *)item {
    // assume itmes without dates are really old
    return [(item.published ?: [NSDate distantPast]) compare:(self.published ?: [NSDate distantPast])];
}

- (NSAttributedString *)attributedStringHighlighted:(BOOL)highlighted {

    NSString *decodedTitle = [(title.length ? title : content) stringByFlatteningHTML]; // fallback to content if no title
    NSString *decodedAuthor = [author stringByFlatteningHTML];

    NSDictionary *titleAtts = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSFont systemFontOfSize:13.0f],NSFontAttributeName,nil];

    if (decodedAuthor.length) {
        NSString *authorSpace = [decodedAuthor stringByAppendingString:@" "];
        
        // if the title begins with the author, it's redundant; trim it out
        if ([decodedTitle rangeOfString:authorSpace].location == 0)
            decodedTitle = [decodedTitle substringFromIndex:authorSpace.length];
        
        decodedAuthor = [decodedAuthor truncatedWithString:@"" afterIndex:15];
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
        decodedTitle = [decodedTitle truncatedAfterIndex:40];
        NSMutableAttributedString *attributed = [[[NSMutableAttributedString alloc] initWithString:decodedTitle] autorelease];
        [attributed addAttributes:titleAtts range:NSMakeRange(0, decodedTitle.length)];
        return attributed;
    }
}

@end
