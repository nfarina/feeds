#import "BitbucketAccount.h"

@implementation BitbucketAccount

+ (void)load { [Account registerClass:self]; }
+ (NSString *)domainSuffix { return @".beanstalkapp.com"; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
+ (NSTimeInterval)defaultRefreshInterval { return 5*60; } // 5 minutes

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = @"https://bitbucket.org/api/1.0/user/repositories/";
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURLString:URL username:self.username password:password];
    URLRequest.HTTPShouldHandleCookies = NO;
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:self context:NULL];
    [self.request addTarget:self action:@selector(meRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

- (void)meRequestComplete:(NSData *)data {
    
    NSDictionary *response = [data objectFromJSONData];
    NSMutableArray *feeds = [[NSMutableArray alloc] init];
    
    for (NSDictionary *repo in response) {
        NSString *URL = [NSString stringWithFormat:@"https://bitbucket.org/api/2.0/repositories/%@/%@/pullrequests/activity", repo[@"owner"], repo[@"slug"]];
        Feed *pullrequestsFeed = [Feed feedWithURLString:URL title:[NSString stringWithFormat: @"%@/%@ - Pull Requests", repo[@"owner"], repo[@"slug"]] account:self];
        pullrequestsFeed.author = self.username;
        pullrequestsFeed.requiresBasicAuth = YES;
        
        [feeds addObject:pullrequestsFeed];
    }
    
    self.feeds = feeds;
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)meRequestError:(NSError *)error {
    if (error.code == 401)
        [self.delegate account:self validationDidFailWithMessage:@"Could not access the given Bitbucket account. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password {
    
    NSMutableArray *items = [NSMutableArray array];
    NSDictionary *response;
    
    NSString *owner = request.request.URL.pathComponents[4];
    NSString *slug = request.request.URL.pathComponents[5];
    
    NSData *newPullRequestData = [self extraDataWithContentsOfURL:[NSURL URLWithString: [NSString stringWithFormat:@"https://bitbucket.org/api/2.0/repositories/%@/%@/pullrequests?sort=-created_on", owner, slug]]];
    response = [newPullRequestData objectFromJSONData];
    NSArray *newPullRequests = response[@"values"];
    
    for (NSDictionary *newPullRequest in newPullRequests) {
        FeedItem *item = [FeedItem new];
        item.rawDate = newPullRequest[@"created_on"];
        item.published = AutoFormatDate(item.rawDate);
        item.updated = item.published;
        item.authorIdentifier = newPullRequest[@"author"][@"username"];
        item.author = newPullRequest[@"author"][@"display_name"];
        item.content = [NSString stringWithFormat: @"<pre style=\"white-space: pre-wrap;\">%@</pre>", newPullRequest[@"description"]];
        item.title = [NSString stringWithFormat:@"%@ created pull request #%@: %@", item.author, newPullRequest[@"id"], newPullRequest[@"title"]];
        
        item.link = [NSURL URLWithString:[NSString stringWithFormat:@"https://bitbucket.org/%@/%@/pull-request/%@", owner, slug, newPullRequest[@"id"]]];
        
        [items addObject:item];
    }

    NSData *mergedPullRequestData = [self extraDataWithContentsOfURL:[NSURL URLWithString: [NSString stringWithFormat:@"https://bitbucket.org/api/2.0/repositories/%@/%@/pullrequests?state=MERGED&sort=-updated_on", owner, slug]]];
    response = [mergedPullRequestData objectFromJSONData];
    NSArray *mergedPullRequests = response[@"values"];
    
    for (NSDictionary *mergedPullRequest in mergedPullRequests) {
        FeedItem *item = [FeedItem new];
        item.rawDate = mergedPullRequest[@"created_on"];
        item.published = AutoFormatDate(item.rawDate);
        item.updated = item.published;
        item.authorIdentifier = mergedPullRequest[@"author"][@"username"];
        item.author = mergedPullRequest[@"author"][@"display_name"];
        item.content = [NSString stringWithFormat: @"<pre style=\"white-space: pre-wrap;\">%@</pre>", mergedPullRequest[@"description"]];
        item.title = [NSString stringWithFormat:@"%@ created pull request #%@: %@", item.author, mergedPullRequest[@"id"], mergedPullRequest[@"title"]];
        
        item.link = [NSURL URLWithString:[NSString stringWithFormat:@"https://bitbucket.org/%@/%@/pull-request/%@", owner, slug, mergedPullRequest[@"id"]]];
        
        [items addObject:item];
    }
    
    // main pull request activity feed
    response = [data objectFromJSONData];
    NSArray *activity = response[@"values"];
    
    for (NSDictionary *activityItem in activity) {
        
        NSString *prTitle = activityItem[@"pull_request"][@"title"];
        NSString *prId = activityItem[@"pull_request"][@"id"];
        NSURL *prLink = [NSURL URLWithString:[NSString stringWithFormat:@"https://bitbucket.org/%@/%@/pull-request/%@", owner, slug, prId]];
        
        FeedItem *item = [FeedItem new];
        
        if ([activityItem objectForKey:@"comment"]) {
            item.rawDate = activityItem[@"comment"][@"created_on"];
            item.published = AutoFormatDate(item.rawDate);
            item.updated = item.published;
            item.authorIdentifier = activityItem[@"comment"][@"user"][@"username"];
            item.author = activityItem[@"comment"][@"user"][@"display_name"];
            item.content = activityItem[@"comment"][@"content"][@"html"];
            item.title = [NSString stringWithFormat:@"%@ commented on pull request #%@: %@", item.author, prId, prTitle];
            
            item.link = [prLink URLByAppendingPathComponent:[NSString stringWithFormat:@"#comment-%@", activityItem[@"comment"][@"id"]]];
        } else if ([activityItem objectForKey:@"approval"]) {
            item.rawDate = activityItem[@"approval"][@"date"];
            item.published = AutoFormatDate(item.rawDate);
            item.updated = item.published;
            item.authorIdentifier = activityItem[@"approval"][@"user"][@"username"];
            item.author = activityItem[@"approval"][@"user"][@"display_name"];
            item.title = [NSString stringWithFormat:@"%@ approved pull request #%@: %@", item.author, prId, prTitle];
            
            item.link = prLink;
        } else {
            continue;
        }
        
        [items addObject:item];
    }
    
    return items;
}

@end
