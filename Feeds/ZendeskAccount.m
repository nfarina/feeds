#import "ZendeskAccount.h"
#import "Feed.h"

@implementation ZendeskAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresDomain { return YES; }
+ (NSString *)domainSuffix { return @".zendesk.com"; }
+ (NSString *)usernameLabel { return @"Email Address:"; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
//- (NSTimeInterval)refreshInterval { return 5*60; } // 5 minutes (via Ilya@Beanstalk)

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = [NSString stringWithFormat:@"https://%@.zendesk.com/api/v2/activities.json", domain];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURLString:URL username:username password:password];
    URLRequest.HTTPShouldHandleCookies = NO;
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:NULL];
    [request addTarget:self action:@selector(activitiesRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(activitiesRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)activitiesRequestComplete:(NSData *)data {
    
    NSString *activityStream = [NSString stringWithFormat:@"https://%@.zendesk.com/api/v2/activities.json", domain];
    
    Feed *feed = [Feed feedWithURLString:activityStream title:@"Activity Stream" account:self];
    feed.author = username; // store author by email address instead of name
    feed.requiresBasicAuth = YES;

    self.feeds = [NSArray arrayWithObject:feed];
    
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)activitiesRequestError:(NSError *)error {    
    if (error.code == 401)
        [self.delegate account:self validationDidFailWithMessage:@"Could not access the given Zendesk domain. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password {
        
    NSMutableArray *items = [NSMutableArray array];

    NSDictionary *response = [data objectFromJSONData];
    NSArray *activities = [response objectForKey:@"activities"];
    
    for (NSDictionary *activity in activities) {

        NSNumber *identifier = [activity objectForKey:@"id"];
        NSString *date = [activity objectForKey:@"created_at"];
        NSDictionary *actor = [activity objectForKey:@"actor"]; // "The actor causing the creation of the activity"
        NSString *actorEmail = [actor objectForKey:@"email"];
        NSString *actorName = [actor objectForKey:@"name"];
        NSString *title = [activity objectForKey:@"title"]; // description really
        NSString *URLString = [activity objectForKey:@"url"];
        
        // Zendesk's "title" is weird - spaces seem to be insignificant (lots of extra spaces), but newlines are significant.
        NSString *content = [[title stringByCondensingSet:[NSCharacterSet whitespaceCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
        
        FeedItem *item = [[FeedItem new] autorelease];
        item.identifier = [identifier stringValue];
        item.rawDate = date;
        item.published = AutoFormatDate(date);
        item.updated = item.published;
        item.authorIdentifier = actorEmail;
        item.author = actorName;
        item.content = content;
        //item.title = [title stringByFlatteningHTML]; // seems to be unnecessary
        item.link = [NSURL URLWithString:URLString];
        
        [items addObject:item];
    }

    return items;
}

@end
