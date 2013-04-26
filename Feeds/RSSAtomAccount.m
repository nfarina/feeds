#import "RSSAtomAccount.h"

@implementation RSSAtomAccount

+ (void)load { [Account registerClass:self]; }
+ (NSString *)friendlyAccountName { return @"RSS/Atom"; }
+ (BOOL)requiresDomain { return YES; }
+ (NSString *)domainLabel { return @"Feed URL:"; }
+ (NSString *)domainPrefix { return @""; }
+ (NSString *)domainSuffix { return @""; }
+ (NSString *)domainPlaceholder { return @"example.com"; }

- (void)validateWithPassword:(NSString *)password {

    NSString *fixedDomain = self.domain;
    
    // prepend http:// if no scheme was specified
    if (![fixedDomain containsString:@"://"])
        fixedDomain = [@"http://" stringByAppendingString:self.domain];
    else if ([fixedDomain beginsWithString:@"feed://"]) // sometimes
        fixedDomain = [fixedDomain stringByReplacingOccurrencesOfString:@"feed://" withString:@"http://"];
    else if ([fixedDomain beginsWithString:@"feed:http://"]) // never seen, but possible
        fixedDomain = [fixedDomain stringByReplacingOccurrencesOfString:@"feed:http://" withString:@"http://"];
    else if ([fixedDomain beginsWithString:@"feed:https://"]) // never seen, but possible
        fixedDomain = [fixedDomain stringByReplacingOccurrencesOfString:@"feed:https://" withString:@"https://"];
    
    NSURLRequest *URLRequest;
    
    // just try fetching the given feed
    if (self.username.length)
        URLRequest = [NSURLRequest requestWithURLString:fixedDomain username:self.username password:password];
    else
        URLRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:fixedDomain]];
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:NULL];
    [self.request addTarget:self action:@selector(feedRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(feedRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

- (void)feedRequestComplete:(NSData *)data {
    
    NSURL *URL = self.request.response.URL; // the final URL of this resource (after any redirects)

    // did this request return HTML?
    BOOL looksLikeHtml = NO;

    if ([self.request.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSString *contentType = [[(NSHTTPURLResponse *)self.request.response allHeaderFields] objectForKey:@"Content-Type"];
        
        if ([contentType isEqualToString:@"text/html"] || [contentType beginsWithString:@"text/html;"] ||
            [URL.path endsWithString:@".html"] || [URL.path endsWithString:@".html"])
            looksLikeHtml = YES;
    }

    // looks like HTML? are you SURE?
    if (looksLikeHtml) {
        
        // peek at the first few bytes of the response
        if (data.length >= 5) {
            NSString *prefix = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 5)] encoding:NSASCIIStringEncoding];
            if ([prefix isEqualToString:@"<?xml"])
                looksLikeHtml = NO; // nope, it's secretly XML! seen this with Zillow's mortgage rates RSS feed
        }
    }
    
    if (looksLikeHtml) {
        
        // Look for feeds in the returned HTML page .
        
        NSMutableArray *foundFeeds = [NSMutableArray array];

        TFHpple *html = [[TFHpple alloc] initWithHTMLData:data];
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
        
        if (self.username.length)
            feed.requiresBasicAuth = YES;
        
        self.feeds = [NSArray arrayWithObject:feed];
    }
    
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)feedRequestError:(NSError *)error {
    
    // if we got a 401, then we can try basic auth if we ask you for your username and password
    if (error.code == 401 && !self.username.length)
        [self.delegate account:self validationDidRequireUsernameAndPasswordWithMessage:@"This feed requires a username/password."];
    else if (error.code == 401 && self.username.length)
        [self.delegate account:self validationDidRequireUsernameAndPasswordWithMessage:@"Could not access the given feed. Please check your username and password."];
    else if (error.code == 404 && self.username.length)
        [self.delegate account:self validationDidFailWithMessage:@"Could not access the given feed. Please check the URL, username, or password." field:AccountFailingFieldUnknown];
    else if (error.code == 404)
        [self.delegate account:self validationDidFailWithMessage:@"Could not access the given feed. The server reports that the URL could not be found." field:AccountFailingFieldDomain];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

@end
