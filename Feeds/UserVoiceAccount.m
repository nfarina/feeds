#import "UserVoiceAccount.h"

@implementation UserVoiceAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresDomain { return YES; }
+ (NSString *)domainSuffix { return @".uservoice.com"; }

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = [NSString stringWithFormat:@"http://%@.uservoice.com", self.domain];
    
    self.request = [SMWebRequest requestWithURL:[NSURL URLWithString:URL] delegate:nil context:NULL];
    [self.request addTarget:self action:@selector(forumRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(forumRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

- (void)forumRequestComplete:(NSData *)data {
    
    TFHpple *html = [[TFHpple alloc] initWithHTMLData:data];
    NSArray *links = [html searchWithXPathQuery:@"//link[@type='application/atom+xml']"];
    
    NSMutableArray *foundFeeds = [NSMutableArray array];

    for (TFHppleElement *link in links) {
        NSString *href = (link.attributes)[@"href"];
        NSString *title = (link.attributes)[@"title"];
        
        // "All activity on feedsapp.uservoice.com" -> "All activity"
        NSString *suffix = [NSString stringWithFormat:@" on %@.uservoice.com",self.domain];
        title = [title stringByReplacingOccurrencesOfString:suffix withString:@""];
        
        Feed *feed = [Feed feedWithURLString:href title:title account:self];
        feed.disabled = ![title containsString:@"All activity"]; // by default, enable "All activity", disable the rest.
        
        if (![foundFeeds containsObject:feed]) // sometimes their HTML contains duplicate feed links.
            [foundFeeds addObject:feed];
    }
    
    self.feeds = foundFeeds;
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)forumRequestError:(NSError *)error {
    if (error.code == 404)
        [self.delegate account:self validationDidFailWithMessage:@"Could not find the given UserVoice account." field:AccountFailingFieldDomain];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

@end
