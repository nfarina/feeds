#import "GithubAccount.h"
#import "JSONKit.h"

typedef enum {
    GithubActivityStarred,
    GithubActivityCreated,
    GithubActivityOpenSourced,
    GithubActivityForked, // last activity with smart content
    GithubActivityOpenedIssue,
    GithubActivityCommentedIssue,
    GithubActivityOpenedPullRequest,
    GithubActivityFollowing
} GithubActivity;

@implementation GithubAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = [NSString stringWithFormat:@"https://github.com/%@.private.atom", self.username];

    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:self.username password:password] delegate:nil context:password];
    [self.request addTarget:self action:@selector(privateFeedRequestComplete:password:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(privateFeedRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

- (void)privateFeedRequestComplete:(NSData *)data password:(NSString *)password {
    
    // OK your username is valid, now look for organizations
    NSString *URL = @"https://api.github.com/user/orgs";
    
    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:self.username password:password] delegate:nil context:nil];
    [self.request addTarget:self action:@selector(orgRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(orgRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
    [self.delegate account:self validationDidContinueWithMessage:@"Finding feeds…"];
}

- (void)privateFeedRequestError:(NSError *)error {
    if (error.code == 401)
        [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Github account. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

- (void)orgRequestComplete:(NSData *)data {

    // Sample result: [{"avatar_url" = "...", id = 321558, login = spotlightmobile, url = "..."}]
    NSArray *orgs = [data objectFromJSONData];
    
    NSString *mainFeedString = [NSString stringWithFormat:@"https://github.com/%@.private.atom", self.username];
    NSString *mainFeedTitle = [NSString stringWithFormat:@"News Feed (%@)", self.username];
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:mainFeedTitle author:self.username account:self];
    mainFeed.requiresBasicAuth = YES;
    
    NSMutableArray *foundFeeds = [NSMutableArray arrayWithObject:mainFeed];

    for (NSDictionary *org in orgs) {
        
        NSString *orgName = org[@"login"];
        NSString *orgFeedString = [NSString stringWithFormat:@"https://github.com/organizations/%@/%@.private.atom", orgName, self.username];
        NSString *orgFeedTitle = [NSString stringWithFormat:@"News Feed (%@)", orgName];
        Feed *orgFeed = [Feed feedWithURLString:orgFeedString title:orgFeedTitle author:self.username account:self];
        orgFeed.requiresBasicAuth = YES;
        [foundFeeds addObject:orgFeed];
    }
    
    self.feeds = foundFeeds;
    
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)orgRequestError:(NSError *)error {
    [self.delegate account:self validationDidFailWithMessage:@"Could not retrieve information about the given Github account. Please check your username and password." field:0];
}

- (GithubActivity)_activityFromTitle:(NSString *)title {
    if ([title containsString:@"starred"]) {
        return GithubActivityStarred;
    }
    else if ([title containsString:@"created"]) {
        return GithubActivityCreated;
    }
    else if ([title containsString:@"open sourced"]) {
        return GithubActivityOpenSourced;
    }
    else if ([title containsString:@"forked"]) {
        return GithubActivityForked;
    }
    else if ([title containsString:@"commented"]) {
        return GithubActivityCommentedIssue;
    }
    else if ([title containsString:@"opened pull request"]) {
        return GithubActivityOpenedPullRequest;
    }
    else if ([title containsString:@"opened issue"]) {
        return GithubActivityOpenedIssue;
    }
    else if ([title containsString:@"following"]) {
        return GithubActivityFollowing;
    }
    NSLog(@"Unexpected activity found in title: %@", title);
    return nil;
}

- (NSString *)smartContentForItem:(FeedItem *)item {
    NSString *link = [item.link absoluteString];
    if (link && [self _activityFromTitle:item.title] <= GithubActivityForked) {
        NSHTTPURLResponse *response = nil;
        NSError *error = nil;
        NSArray *linkParts = [link componentsSeparatedByString:@"/"];
        NSString *repo = [linkParts objectAtIndex:[linkParts count] - 1];
        NSString *owner = [linkParts objectAtIndex:[linkParts count] - 2];
        NSURL *githubURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/repos/%@/%@", owner, repo]];
        NSURLRequest *request = [NSURLRequest requestWithURL:githubURL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:0.5];
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if ([response statusCode] == 200) {
            NSDictionary *githubObject = [data objectFromJSONData];
            if (githubObject) {
                return [githubObject objectForKey:@"description"];
            }
        }
        
    }
    return item.content;
}

@end
