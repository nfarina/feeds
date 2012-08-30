#import "PivotalTrackerAccount.h"

@implementation PivotalTrackerAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
+ (NSString *)friendlyAccountName { return @"Pivotal Tracker"; }

- (void)validateWithPassword:(NSString *)password {
    
    NSURL *URL = [NSURL URLWithString:@"https://www.pivotaltracker.com/services/v3/tokens/active"];
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL username:self.username password:password];
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:NULL];
    [request addTarget:self action:@selector(tokenRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(tokenRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

/*
 <?xml version="1.0" encoding="UTF-8"?>
 <token>
    <guid>49f4bbea92daafdb22b0249be2b46717</guid>
    <id type="integer">123261</id>
 </token>
 */
- (void)tokenRequestComplete:(NSData *)data {
    
    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:NULL];
    NSString *token = [document.root valueWithPath:@"guid"];
    
    if (token) {

        NSString *URL = @"https://www.pivotaltracker.com/services/v3/projects";
        
        NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]];
        [URLRequest setValue:token forHTTPHeaderField:@"X-TrackerToken"];
        
        self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:nil context:token];
        [request addTarget:self action:@selector(projectsRequestComplete:token:) forRequestEvents:SMWebRequestEventComplete];
        [request addTarget:self action:@selector(genericRequestError:) forRequestEvents:SMWebRequestEventError];
        [request start];
        [delegate account:self validationDidContinueWithMessage:@"Finding projects…"];
    }
    else {
        [self.delegate account:self validationDidFailWithMessage:@"Could not retrieve some information for the given Pivotal Tracker account. Please check your username and password." field:0];
    }
}

- (void)tokenRequestError:(NSError *)error {
    if (error.code == 401)
        [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Pivotal Tracker account. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

/*
<?xml version="1.0" encoding="UTF-8"?>
<projects type="array">
  <project>
    <id>621331</id>
    <name>My Sample Project 2</name>
    <account>feedsapp</account>
    ...
    <memberships type="array">
      <membership>
        <id>2251021</id>
        <person>
          <email>nick@feedsapp.com</email>
          <name>Nick Farina</name>
          <initials>NF</initials>
        </person>
        <role>Owner</role>
      </membership>
    </memberships>
  </project>
</projects>
 */
- (void)projectsRequestComplete:(NSData *)data token:(NSString *)token {

    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:NULL];
    NSArray *projects = [document.root childrenNamed:@"project"];
    NSMutableArray *foundFeeds = [NSMutableArray array];
    
    // look at any project's memberships to try and discover our own name (knowing our username is our email)
    NSString *author = nil;
    
    SMXMLElement *project = projects.firstObject;
    for (SMXMLElement *membership in [project childNamed:@"memberships"].children)
        if ([[membership valueWithPath:@"person.email"] isEqualToString:self.username]) {
            author = [membership valueWithPath:@"person.name"];
            break;
        }

    if (author) {
        
        NSString *mainFeedString = [NSString stringWithFormat:@"https://www.pivotaltracker.com/services/v3/activities?limit=30"];
        Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:@"All Activity" author:author account:self];
        mainFeed.requestHeaders = @{ @"X-TrackerToken" : token, @"X-Tracker-Use-UTC": @"true" };
        [foundFeeds addObject:mainFeed];
        
        for (SMXMLElement *project in projects) {
            
            NSString *projectID = [project valueWithPath:@"id"];
            NSString *projectName = [project valueWithPath:@"name"];
            NSString *projectFeedString = [NSString stringWithFormat:@"https://www.pivotaltracker.com/services/v3/projects/%@/activities?limit=30", projectID];
            
            Feed *projectFeed = [Feed feedWithURLString:projectFeedString title:projectName author:author account:self];
            projectFeed.requestHeaders = @{ @"X-TrackerToken": token, @"X-Tracker-Use-UTC": @"true" };
            projectFeed.disabled = YES;
            
            [foundFeeds addObject:projectFeed];
        }
        
        self.feeds = foundFeeds;
        [self.delegate account:self validationDidCompleteWithNewPassword:nil];
    }
    else {
        [self.delegate account:self validationDidFailWithMessage:@"Could not find any projects accessible by this account. Feeds requires you to have access to at least one project." field:0];
    }
}

- (void)genericRequestError:(NSError *)error {
    [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

/*
<?xml version="1.0" encoding="UTF-8"?>
<activities type="array">
  <activity>
    <id type="integer">234905237</id>
    <occurred_at type="datetime">2012/08/18 01:42:18 UTC</occurred_at>
    <author>Feeds Testing</author>
    <project_id type="integer">621331</project_id>
    <description>Feeds Testing added comment: &quot;Doesn't anything make RSS?&quot;</description>
    <stories type="array">
      <story>
        <id type="integer">34601811</id>
        <url>http://www.pivotaltracker.com/services/v3/projects/621331/stories/34601811</url>
        <notes type="array">
          <note>
            <id type="integer">27386657</id>
            <text>Doesn't anything make RSS?</text>
          </note>
        </notes>
      </story>
    </stories>
  </activity>
  ...
</activities>
 */
+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password {
    
    NSMutableArray *items = [NSMutableArray array];
    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:NULL];
    
    for (SMXMLElement *activity in document.root.children) {
        
        NSString *identifier = [activity valueWithPath:@"id"];
        NSString *date = [activity valueWithPath:@"occurred_at"];
        NSString *author = [activity valueWithPath:@"author"];
        NSString *description = [activity valueWithPath:@"description"];
        NSString *projectIdentifier = [activity valueWithPath:@"project_id"];
        NSString *storyIdentifier = [activity valueWithPath:@"stories.story.id"]; // just pick the first story

        NSString *projectLookup = [NSString stringWithFormat:@"https://www.pivotaltracker.com/services/v3/projects/%@",projectIdentifier];
        NSMutableURLRequest *projectRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:projectLookup]];
        projectRequest.allHTTPHeaderFields = request.request.allHTTPHeaderFields; // copy token header for auth
        
        NSData *projectData = [self extraDataWithContentsOfURLRequest:projectRequest];
        SMXMLDocument *projectDocument = [SMXMLDocument documentWithData:projectData error:NULL];
        NSString *projectName = [projectDocument.root valueWithPath:@"name"];

        FeedItem *item = [[FeedItem new] autorelease];
        item.rawDate = date;
        item.project = projectName;
        item.identifier = identifier;
        item.published = AutoFormatDate(date);
        item.updated = item.published;
        item.author = author;
        item.content = description;
        if (storyIdentifier) {
            NSString *URLString = [NSString stringWithFormat:@"https://www.pivotaltracker.com/story/show/%@",storyIdentifier];
            item.link = [NSURL URLWithString:URLString];
        }
        [items addObject:item];
    }
    
    return items;
}

@end
