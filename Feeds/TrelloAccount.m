#import "TrelloAccount.h"

@implementation TrelloAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresAuth { return YES; }
+ (BOOL)requiresDomain { return NO; }
+ (BOOL)requiresUsername { return NO; }
+ (BOOL)requiresPassword { return NO; }
+ (NSTimeInterval)defaultRefreshInterval { return 5*60; } // 5 minutes

- (void)beginAuth {
    NSURL *URL = [NSURL URLWithString:@"https://trello.com/1/connect?key=53e6bb99cefe4914e88d06c76308e357&name=Feeds&return_url=feedsapp://trello/auth"];
    [[NSWorkspace sharedWorkspace] openURL:URL];
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

    NSString *URL = [NSString stringWithFormat:@"https://api.trello.com/1/members/me?key=53e6bb99cefe4914e88d06c76308e357&token=%@", token];
    
    self.request = [SMWebRequest requestWithURL:[NSURL URLWithString:URL] delegate:nil context:token];
    [request addTarget:self action:@selector(meRequestComplete:context:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestComplete:(NSData *)data context:(NSString *)token {
    
    NSDictionary *me = [data objectFromJSONData];
    self.username = [me objectForKey:@"username"];

    NSString *mainFeedString = [NSString stringWithFormat:@"https://api.trello.com/1/members/me/notifications?key=53e6bb99cefe4914e88d06c76308e357&token=%@", token];
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:@"All Notifications" author:self.username account:self];
    
    self.feeds = [NSArray arrayWithObject:mainFeed];
    
    [self.delegate account:self validationDidCompleteWithNewPassword:token];
}

- (void)meRequestError:(NSError *)error {
    [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)token {
        
    NSMutableArray *items = [NSMutableArray array];
    NSArray *notifications = [data objectFromJSONData];

    for (NSDictionary *notification in notifications) {
        
        FeedItem *item = [[FeedItem new] autorelease];
        
        NSString *type = [notification objectForKey:@"type"];
        NSString *date = [notification objectForKey:@"date"];
        NSString *creatorIdentifier = [notification objectForKey:@"idMemberCreator"];
        NSDictionary *data = [notification objectForKey:@"data"];
        NSString *org = [[data objectForKey:@"organization"] objectForKey:@"id"];
        NSString *orgName = [[data objectForKey:@"organization"] objectForKey:@"name"];
        NSString *board = [[data objectForKey:@"board"] objectForKey:@"id"];
        NSString *boardName = [[data objectForKey:@"board"] objectForKey:@"name"];
        NSString *card = [[data objectForKey:@"card"] objectForKey:@"id"];
        NSString *cardName = [[data objectForKey:@"card"] objectForKey:@"name"];
        NSString *member = [[data objectForKey:@"member"] objectForKey:@"id"];
        NSString *name = [data objectForKey:@"name"];
        NSString *text = [data objectForKey:@"text"];
        NSString *state = [data objectForKey:@"state"];
        NSString *URLString = nil;

        item.rawDate = date;
        item.published = AutoFormatDate(date);
        item.updated = item.published;
        
        if (!item.published) DDLogError(@"Couldn't parse date %@", date);

        if (card && board)
            URLString = [NSString stringWithFormat:@"https://trello.com/card/board/%@/%@",board,card];
        else if (board)
            URLString = [NSString stringWithFormat:@"https://trello.com/board/%@",board];
        else if (org)
            URLString = [NSString stringWithFormat:@"https://trello.com/org/%@",org];

        if (URLString)
            item.link = [NSURL URLWithString:URLString];

        NSString *title = nil;
        
        if ([type isEqualToString:@"addedToBoard"])
            title = @"added you to board {board}";
        else if ([type isEqualToString:@"addedToCard"])
            title = @"added you to card {card}";
        else if ([type isEqualToString:@"addedMemberToCard"])
            title = @"added {member} to card {card}";
        else if ([type isEqualToString:@"addAdminToBoard"])
            title = @"added you as admin to board {board}";
        else if ([type isEqualToString:@"addAdminToOrganization"])
            title = @"added you as admin to organization {org}";
        else if ([type isEqualToString:@"changeCard"])
            title = @"changed card {card}";
        else if ([type isEqualToString:@"closeBoard"])
            title = @"closed board {board}";
        else if ([type isEqualToString:@"commentCard"])
            title = @"commented on card {card}";
        else if ([type isEqualToString:@"invitedToBoard"])
            title = @"invited you to board {board}";
        else if ([type isEqualToString:@"invitedToOrganization"])
            title = @"invited you to organization {org}";
        else if ([type isEqualToString:@"removedFromBoard"])
            title = @"removed you from board {board}";
        else if ([type isEqualToString:@"removedFromCard"])
            title = @"removed you from card {card}";
        else if ([type isEqualToString:@"removedMemberFromCard"])
            title = @"removed {member} from card {card}";
        else if ([type isEqualToString:@"removedFromOrganization"])
            title = @"removed you from organization {org}";
        else if ([type isEqualToString:@"mentionedOnCard"])
            title = @"mentioned you on card {card}";
        else if ([type isEqualToString:@"updateCheckItemStateOnCard"] && [state isEqualToString:@"complete"]) {
            title = @"checked an item on card {card}";
            text = [NSString stringWithFormat:@"✓ %@", name];
        }
        else if ([type isEqualToString:@"updateCheckItemStateOnCard"] && [state isEqualToString:@"incomplete"]) {
            title = @"unchecked an item on card {card}";
            text = [NSString stringWithFormat:@"- %@", name];
        }
        else
            title = type;
        
        if ([title containsString:@"{member}"] && member) {
            
            if ([member isEqualToString:creatorIdentifier]) {
                title = [title stringByReplacingOccurrencesOfString:@"{member}" withString:@"self"];
            }
            else {
                // go out and fetch the related member since we only have their ID
                NSString *authorLookup = [NSString stringWithFormat:@"https://api.trello.com/1/members/%@?key=53e6bb99cefe4914e88d06c76308e357&token=%@", member, token];
                NSData *data = [self extraDataWithContentsOfURL:[NSURL URLWithString:authorLookup]];
                if (!data) return nil;
                
                NSDictionary *member = [data objectFromJSONData];
                NSString *memberName = [member objectForKey:@"fullName"];
                
                title = [title stringByReplacingOccurrencesOfString:@"{member}" withString:memberName ?: @""];
            }
        }

        title = [title stringByReplacingOccurrencesOfString:@"{org}" withString:
                 [NSString stringWithFormat:@"<b>%@</b>", orgName ?: @""]];
        title = [title stringByReplacingOccurrencesOfString:@"{board}" withString:
                 [NSString stringWithFormat:@"<b>%@</b>", boardName ?: @""]];
        title = [title stringByReplacingOccurrencesOfString:@"{card}" withString:
                 [NSString stringWithFormat:@"<b>%@</b>", cardName ?: @""]];
                    
        if (creatorIdentifier) {
            // go out and fetch the author's username since we only have their ID
            NSString *authorLookup = [NSString stringWithFormat:@"https://api.trello.com/1/members/%@?key=53e6bb99cefe4914e88d06c76308e357&token=%@", creatorIdentifier, token];
            NSData *data = [self extraDataWithContentsOfURL:[NSURL URLWithString:authorLookup]];
            if (!data) return nil;
            
            NSDictionary *member = [data objectFromJSONData];
            NSString *memberName = [member objectForKey:@"fullName"];
            item.author = memberName;
        }
        
        if (item.author.length)
            title = [NSString stringWithFormat:@"%@ %@", item.author, title];
        
        NSString *content = title;
        
        if (text)
            content = [content stringByAppendingFormat:@"<hr/><i>%@</i>", text];

        //item.title = title;
        item.content = content;
        item.project = boardName;
        
        [items addObject:item];
    }
    
    return items;
}

@end
