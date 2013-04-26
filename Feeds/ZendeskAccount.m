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
    
    if (![self.username isValidEmailAddress]) {
        [self.delegate account:self validationDidFailWithMessage:@"Please enter a valid email address." field:AccountFailingFieldUsername];
        return;
    }

    NSString *URL = [NSString stringWithFormat:@"https://%@.zendesk.com/api/v2/activities.json", self.domain];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURLString:URL username:self.username password:password];
    URLRequest.HTTPShouldHandleCookies = NO;
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:NULL];
    [self.request addTarget:self action:@selector(activitiesRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(activitiesRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

- (void)activitiesRequestComplete:(NSData *)data {
    
    NSString *activityStream = [NSString stringWithFormat:@"https://%@.zendesk.com/api/v2/activities.json", self.domain];
    
    Feed *feed = [Feed feedWithURLString:activityStream title:@"Activity Stream" account:self];
    feed.author = self.username; // store author by email address instead of name
    feed.requiresBasicAuth = YES;

    self.feeds = @[feed];
    
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
    NSArray *activities = response[@"activities"];
    
    for (NSDictionary *activity in activities) {

        NSNumber *identifier = activity[@"id"];
        NSString *date = activity[@"created_at"];
        NSDictionary *actor = activity[@"actor"]; // "The actor causing the creation of the activity"
        NSString *actorEmail = actor[@"email"];
        NSString *actorName = actor[@"name"];
        NSString *title = activity[@"title"]; // description really
        NSDictionary *target = activity[@"target"]; // the ticket
        NSDictionary *ticket = target[@"ticket"];
        NSNumber *ticketIdentifier = ticket[@"id"];
        NSString *ticketSubject = ticket[@"subject"];
        NSDictionary *object = activity[@"object"]; // the comment or whatever that this activity reports about
        NSDictionary *comment = object[@"comment"]; // if present
        NSDictionary *commentValue = comment[@"value"];
        
        // Zendesk's "title" is weird - spaces seem to be insignificant (lots of extra spaces), but newlines are significant.
        //NSString *content = [[title stringByCondensingSet:[NSCharacterSet whitespaceCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
        
        NSString *content = [NSString stringWithFormat:@"Subject: <b>%@</b>", ticketSubject];
        
        if (commentValue)
            content = [content stringByAppendingFormat:@"<hr/><i>%@</i>", commentValue];
        
        NSString *URLString = [NSString stringWithFormat:@"https://%@.zendesk.com/tickets/%@",domain,ticketIdentifier];
        
        FeedItem *item = [FeedItem new];
        item.identifier = [identifier stringValue];
        item.rawDate = date;
        item.published = AutoFormatDate(date);
        item.updated = item.published;
        item.authorIdentifier = actorEmail;
        item.author = actorName;
        item.content = content;
        item.title = [title stringByFlatteningHTML]; // seems to be unnecessary
        item.link = [NSURL URLWithString:URLString];
        
        [items addObject:item];
    }

    return items;
}

@end
