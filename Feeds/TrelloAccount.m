#import "TrelloAccount.h"

@implementation TrelloAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresDomain { return NO; }
+ (BOOL)requiresUsername { return NO; }
+ (BOOL)requiresPassword { return NO; }
+ (NSURL *)requiredAuthURL {
    return [NSURL URLWithString:@"https://trello.com/1/connect?key=53e6bb99cefe4914e88d06c76308e357&name=Feeds&return_url=feedsapp://trello/auth"];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data {
    if ([request.request.URL.host isEqualToString:@"api.trello.com"]) {
        
        NSMutableArray *items = [NSMutableArray array];
        NSArray *notifications = [data objectFromJSONData];
        
        for (NSDictionary *notification in notifications) {
            
            FeedItem *item = [[FeedItem new] autorelease];
            item.title = [notification objectForKey:@"type"];
            [items addObject:item];
        }
        
        return items;
    }
    else return nil;
}

- (void)authWasFinishedWithURL:(NSURL *)url {
    NSString *fragment = [url fragment]; // #token=xyz

    if (![fragment beginsWithString:@"token="]) {
        [self.delegate account:self validationDidFailWithMessage:@"" field:AccountFailingFieldAuth];
        return;
    }
    
    NSArray *parts = [fragment componentsSeparatedByString:@"="];
    NSString *token = [parts objectAtIndex:1]; // xyz
    
    [self validateWithPassword:token];
}

- (void)validateWithPassword:(NSString *)token {
    
    NSString *mainFeedString = [NSString stringWithFormat:@"https://api.trello.com/1/members/me/notifications?key=53e6bb99cefe4914e88d06c76308e357&token=%@", token];
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:@"All Notifications" account:self];
    
//    if ([firstName length] > 0 && [lastName length] > 0)
//        mainFeed.author = [NSString stringWithFormat:@"%@ %@.", firstName, [lastName substringToIndex:1]];
    
    self.feeds = [NSArray arrayWithObject:mainFeed];
    
    [self.delegate account:self validationDidCompleteWithPassword:token];
}

@end
