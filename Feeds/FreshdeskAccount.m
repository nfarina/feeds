#import "FreshdeskAccount.h"

@implementation FreshdeskAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresDomain { return YES; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
+ (NSString *)usernameLabel { return @"Email Address:"; }
+ (NSString *)domainSuffix { return @".freshdesk.com"; }

- (void)validateWithPassword:(NSString *)password {
  
    NSString *URL = [NSString stringWithFormat:@"https://%@.freshdesk.com/helpdesk/tickets.json", self.domain];
    
    self.request = [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURLString:URL username:self.username password:password] delegate:nil context:NULL];
    [self.request addTarget:self action:@selector(meRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

- (void)meRequestComplete:(NSData *)data {
    if([[NSString stringWithUTF8String:[data bytes]] isEqualToString:@"{\"require_login\":true}"]){
      [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Freshdesk account. Please check your domain, username, and password." field:0];
      return;
    }
   
    NSString *mainFeedString = [NSString stringWithFormat:@"https://%@.freshdesk.com/helpdesk/tickets.json", self.domain];
    NSLog(@"%@", mainFeedString);
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:@"Helpdesk Tickets" account:self];
    mainFeed.requiresBasicAuth = YES;
    mainFeed.author = self.username;
    self.feeds = @[mainFeed];
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)meRequestError:(NSError *)error {
    if (error.code != 200)
        [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Freshdesk account. Please check your domain, username, and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password {
   
    NSMutableArray *items = [NSMutableArray array];
    NSArray *events = [data objectFromJSONData];
   
    for (NSDictionary *event in events) {
      NSLog(@"%@",event[@"0"]);
      NSString *date = event[@"updated_at"];
      FeedItem *item = [FeedItem new];
      item.rawDate = date;
      item.published = AutoFormatDate(date);
      item.updated = item.published;
      item.title = event[@"subject"];
      item.author = event[@"requester_name"];
      item.content = event[@"description_html"];
      item.link = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@.freshdesk.com/helpdesk/tickets/%@",domain, event[@"display_id"]]];
      item.authoredByMe = NO; // I guess this can just be always NO, right?
      [items addObject:item];
    }
   
    return items;
}

@end
