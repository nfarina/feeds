#import "GenericFeedAccount.h"

@implementation GenericFeedAccount

+ (void)load { [Account registerClass:self]; }
+ (NSString *)friendlyAccountName { return @"RSS/Atom Feed"; }
+ (BOOL)requiresDomain { return YES; }
+ (NSString *)domainLabel { return @"Feed URL:"; }
+ (NSString *)domainPrefix { return @""; }
+ (NSString *)domainSuffix { return @""; }
+ (NSString *)domainPlaceholder { return @"http://example.com/feed.rss"; }

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
    
    attemptedAutoFeedDiscovery = NO; // reset this in case you're trying again
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:NULL];
    [request addTarget:self action:@selector(feedRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(feedRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)feedRequestComplete:(NSData *)data {
    
    // only do this once per validation attempt
    if (!attemptedAutoFeedDiscovery) {
        attemptedAutoFeedDiscovery = YES;
        
        // did this request return HTML? Maybe we can find a feed in there.
        NSString *contentType = [[(NSHTTPURLResponse *)self.request.response allHeaderFields] objectForKey:@"Content-Type"];
        if ([contentType isEqualToString:@"text/html"] || [contentType beginsWithString:@"text/html;"]) {
            
            TFHpple *html = [[[TFHpple alloc] initWithHTMLData:data] autorelease];
            NSArray *rssLinks = [html searchWithXPathQuery:@"//link[@type='application/rss+xml']"];
            NSArray *atomLinks = [html searchWithXPathQuery:@"//link[@type='application/atom+xml']"];
            
            for (TFHppleElement *link in [rssLinks arrayByAddingObjectsFromArray:atomLinks]) {
                NSString *href = [link.attributes objectForKey:@"href"];
                
                if (href.length) {
                    // try re-requesting this instead
                    self.request = [SMWebRequest requestWithURL:[NSURL URLWithString:href] delegate:nil context:NULL];
                    [request addTarget:self action:@selector(feedRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
                    [request addTarget:self action:@selector(feedRequestError:) forRequestEvents:SMWebRequestEventError];
                    [request start];
                    return;
                }
            }
        }
    }
    
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
    
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)feedRequestError:(NSError *)error {
    
    NSLog(@"Error! %@", error);
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
