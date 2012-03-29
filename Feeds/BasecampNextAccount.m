#import "BasecampNextAccount.h"

@implementation BasecampNextAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresDomain { return YES; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
+ (NSString *)domainLabel { return @"Account ID:"; }
+ (NSString *)domainPrefix { return @"https://basecamp.com/"; }
+ (NSString *)friendlyAccountName { return @"Basecamp Next"; }

- (void)validateWithPassword:(NSString *)password {

    NSString *URL = [NSString stringWithFormat:@"https://basecamp.com/%@/api/v1/projects.json", domain];
    
    NSURLRequest *URLRequest = [NSURLRequest requestWithURLString:URL username:username password:password];
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:password];
    [request addTarget:self action:@selector(meRequestComplete:password:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestComplete:(NSData *)data password:(NSString *)password {

//    NSDictionary *response = [data objectFromJSONData];

    NSString *URL = [NSString stringWithFormat:@"https://basecamp.com/%@/api/v1/projects.json", domain];

    NSURLRequest *URLRequest = [NSURLRequest requestWithURLString:URL username:username password:password];

    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:NULL];
    [request addTarget:self action:@selector(projectsRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(projectsRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    if (error.code == 404)
        [self.delegate account:self validationDidFailWithMessage:@"Could not find the given Basecamp account. Please verify that your Account ID matches the number found in your browser's address bar." field:AccountFailingFieldDomain];
    else if (error.code == 500)
        [self.delegate account:self validationDidFailWithMessage:@"There was a problem signing in to the given Basecamp account. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

- (void)projectsRequestComplete:(NSData *)data {
    
    NSArray *projects = [data objectFromJSONData];
    
    NSString *mainFeedString = [NSString stringWithFormat:@"https://basecamp.com/%@/api/v1/events.json", domain];
    NSString *mainFeedTitle = @"All Events";
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:mainFeedTitle author:nil account:self];
    mainFeed.requiresBasicAuth = YES;
    
    NSMutableArray *foundFeeds = [NSMutableArray arrayWithObject:mainFeed];
    
    for (NSDictionary *project in projects) {
        
        NSString *projectName = [project objectForKey:@"name"];
        NSString *projectIdentifier = [project objectForKey:@"id"];
        NSString *projectFeedString = [NSString stringWithFormat:@"https://basecamp.com/%@/api/v1/projects/%@/events.json", domain, projectIdentifier];
        NSString *projectFeedTitle = [NSString stringWithFormat:@"Events for project \"%@\"", projectName];
        Feed *projectFeed = [Feed feedWithURLString:projectFeedString title:projectFeedTitle author:nil account:self];
        projectFeed.requiresBasicAuth = YES;
        projectFeed.disabled = YES; // disable by default, only enable All Events
        [foundFeeds addObject:projectFeed];
    }
    
    self.feeds = foundFeeds;
    
    [self.delegate account:self validationDidCompleteWithPassword:nil];
}

- (void)projectsRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    [self.delegate account:self validationDidFailWithMessage:@"Could not retrieve information about the given Basecamp Next account. Please contact support@feedsapp.com." field:0];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password {
    if ([request.request.URL.host isEqualToString:@"basecamp.com"]) {
        
        NSMutableArray *items = [NSMutableArray array];

        NSArray *events = [data objectFromJSONData];
        
        for (NSDictionary *event in events) {
            
            NSString *date = [event objectForKey:@"created_at"];
            NSDictionary *bucket = [event objectForKey:@"bucket"];
            NSDictionary *creator = [event objectForKey:@"creator"];
            NSNumber *creatorIdentifier = [creator objectForKey:@"id"];
            
            FeedItem *item = [[FeedItem new] autorelease];
            item.rawDate = date;
            item.published = AutoFormatDate(date);
            item.updated = item.published;
            item.authorIdentifier = [creatorIdentifier stringValue];
            item.author = [creator objectForKey:@"name"];
            item.content = [event objectForKey:@"summary"];
            item.project = [bucket objectForKey:@"name"];
//            item.title = [NSString stringWithFormat:@"%@ %@", item.author, item.content];
            [items addObject:item];
        }
        
        return items;
    }
    else return nil;
}

@end
