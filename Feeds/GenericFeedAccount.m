#import "GenericFeedAccount.h"

@implementation GenericFeedAccount

+ (void)load { [Account registerClass:self]; }
+ (NSString *)friendlyAccountName { return @"RSS/Atom"; }
+ (BOOL)requiresDomain { return YES; }
+ (NSString *)domainLabel { return @"Feed URL:"; }
+ (NSString *)domainPrefix { return @""; }
+ (NSString *)domainSuffix { return @""; }
+ (NSString *)domainPlaceholder { return @"example.com"; }

- (void)validateWithPassword:(NSString *)password {

    NSString *fixedDomain = domain;
    
    // prepend http:// if no scheme was specified
    if (![fixedDomain containsString:@"://"])
        fixedDomain = [@"http://" stringByAppendingString:domain];
    
    NSURLRequest *URLRequest;
    
    // just try fetching the given feed
    if (username.length)
        URLRequest = [NSURLRequest requestWithURLString:fixedDomain username:username password:password];
    else
        URLRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:fixedDomain]];
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:NULL];
    [request addTarget:self action:@selector(feedRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(feedRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

//- (NSURLRequest *)webRequest:(SMWebRequest *)webRequest willSendRequest:(NSURLRequest *)newRequest redirectResponse:(NSURLResponse *)redirectResponse {
//    if (redirectResponse) {
//        // make sure to remember where we were redirected to, for 
//    }
//    return newRequest;
//}

- (void)feedRequestComplete:(NSData *)data {
    
    NSURL *URL = self.request.response.URL; // the final URL of this resource (after any redirects)
    
    // did this request return HTML? Look for feeds in there.
    NSString *contentType = nil;
    if ([self.request.response isKindOfClass:[NSHTTPURLResponse class]])
        contentType = [[(NSHTTPURLResponse *)self.request.response allHeaderFields] objectForKey:@"Content-Type"];
    
    if ([contentType isEqualToString:@"text/html"] || [contentType beginsWithString:@"text/html;"] ||
        [URL.path endsWithString:@".html"] || [URL.path endsWithString:@".html"]) {
        
        NSMutableArray *foundFeeds = [NSMutableArray array];

        TFHpple *html = [[[TFHpple alloc] initWithHTMLData:data] autorelease];
        NSArray *rssLinks = [html searchWithXPathQuery:@"//link[@type='application/rss+xml']"];
        NSArray *atomLinks = [html searchWithXPathQuery:@"//link[@type='application/atom+xml']"];
        
        for (TFHppleElement *link in rssLinks) {
            NSString *href = [link.attributes objectForKey:@"href"];
            NSString *title = [link.attributes objectForKey:@"title"] ?: @"RSS Feed";
            NSURL *url = [NSURL URLWithString:href relativeToURL:URL];
            
            if (href.length) {
                Feed *feed = [Feed feedWithURLString:url.absoluteString title:title account:self];
                if (![foundFeeds containsObject:feed]) [foundFeeds addObject:feed]; // check for duplicates
            }
        }
        
        for (TFHppleElement *link in atomLinks) {
            NSString *href = [link.attributes objectForKey:@"href"];
            NSString *title = [link.attributes objectForKey:@"title"] ?: @"Atom Feed";
            NSURL *url = [NSURL URLWithString:href relativeToURL:URL];
            
            if (href.length) {
                Feed *feed = [Feed feedWithURLString:url.absoluteString title:title account:self];
                if (![foundFeeds containsObject:feed]) [foundFeeds addObject:feed]; // check for duplicates
            }
        }
        
        if (foundFeeds.count)
            self.feeds = foundFeeds;
        else {
            [self.delegate account:self validationDidFailWithMessage:@"Could not discover any feeds at the given URL. Try specifying the complete URL to the feed." field:AccountFailingFieldDomain];
            return;
        }
    }
    else {
        // make sure we can parse this feed, and snag the title if we can!
        NSString *title; NSError *error;
        NSArray *items = [Feed feedItemsWithData:data discoveredTitle:&title error:&error];
        
        if (items == nil) {
            NSString *message = [NSString stringWithFormat:@"Could not parse the given feed. Error: %@", error.localizedDescription];
            [self.delegate account:self validationDidFailWithMessage:message field:AccountFailingFieldUnknown];
            return;
        }
        
        Feed *feed = [Feed feedWithURLString:self.request.request.URL.absoluteString title:(title ?: @"All Items") account:self];
        
        if (username.length)
            feed.requiresBasicAuth = YES;
        
        self.feeds = [NSArray arrayWithObject:feed];
    }
    
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)feedRequestError:(NSError *)error {
    
    // if we got a 401, then we can try basic auth if we ask you for your username and password
    if (error.code == 401 && !username.length)
        [self.delegate account:self validationDidRequireUsernameAndPasswordWithMessage:@"This feed requires a username/password."];
    else if (error.code == 401 && username.length)
        [self.delegate account:self validationDidRequireUsernameAndPasswordWithMessage:@"Could not access the given feed. Please check your username and password."];
    else if (error.code == 404 && username.length)
        [self.delegate account:self validationDidFailWithMessage:@"Could not access the given feed. Please check the URL, username, or password." field:AccountFailingFieldUnknown];
    else if (error.code == 404)
        [self.delegate account:self validationDidFailWithMessage:@"Could not access the given feed. The server reports that the URL could not be found." field:AccountFailingFieldDomain];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

@end
