#import "BeanstalkAccount.h"

@implementation BeanstalkAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresDomain { return YES; }
+ (NSString *)domainSuffix { return @".beanstalkapp.com"; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
- (NSTimeInterval)refreshInterval { return 5*60; } // 5 minutes (via Ilya@Beanstalk)

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/users/current.json", domain];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURLString:URL username:username password:password];
    URLRequest.HTTPShouldHandleCookies = NO;
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:self context:NULL];
    [request addTarget:self action:@selector(meRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [request start];
}

- (void)meRequestComplete:(NSData *)data {
    
    NSDictionary *response = [data objectFromJSONData];
    NSDictionary *user = [response objectForKey:@"user"];
    
    NSString *changesets = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/changesets.json", domain];
    Feed *changesetsFeed = [Feed feedWithURLString:changesets title:@"Changesets" account:self];
    changesetsFeed.author = [user objectForKey:@"id"]; // store author by unique identifier instead of name
    changesetsFeed.requiresBasicAuth = YES;

    NSString *releases = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/releases.json", domain];
    Feed *releasesFeed = [Feed feedWithURLString:releases title:@"Deployments" account:self];
    releasesFeed.author = [user objectForKey:@"id"]; // store author by unique identifier instead of name
    releasesFeed.requiresBasicAuth = YES;

    self.feeds = [NSArray arrayWithObjects:changesetsFeed, releasesFeed, nil];

    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (NSURLRequest *)webRequest:(SMWebRequest *)webRequest willSendRequest:(NSURLRequest *)newRequest redirectResponse:(NSURLResponse *)redirectResponse {
    
    if (redirectResponse) {
        [self.delegate account:self validationDidFailWithMessage:@"The given Beanstalk domain could not be found." field:AccountFailingFieldDomain];
        self.request = nil; // cancel
        return nil;
    }
    else return newRequest;
}

- (void)meRequestError:(NSError *)error {
    NSLog(@"Error! %@", error);
    
    SMErrorResponse *response = [error.userInfo objectForKey:SMErrorResponseKey];
    NSString *message = nil;
    
    if ([[response.response.allHeaderFields objectForKey:@"Content-Type"] beginsWithString:@"application/json"]) {
        NSDictionary *data = [response.data objectFromJSONData];
        NSArray *errors = [data objectForKey:@"errors"];
        message = errors.count ? [errors objectAtIndex:0] : nil;
    }
    
    if (error.code == 500 && message)
        [self.delegate account:self validationDidFailWithMessage:message field:AccountFailingFieldUnknown];
    else if (error.code == 401)
        [self.delegate account:self validationDidFailWithMessage:@"Could not access the given Beanstalk domain. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password {
    if ([request.request.URL.host endsWithString:self.domainSuffix]) {
        
        NSMutableArray *items = [NSMutableArray array];
        
        if ([request.request.URL.path isEqualToString:@"/api/changesets.json"]) {
            
            NSArray *changesets = [data objectFromJSONData];
            
            for (NSDictionary *changeset in changesets) {
                
                NSDictionary *revision = [changeset objectForKey:@"revision_cache"];
                NSNumber *repositoryIdentifier = [revision objectForKey:@"repository_id"];
                NSNumber *userIdentifier = [revision objectForKey:@"user_id"];
                NSString *date = [revision objectForKey:@"time"];
                NSString *message = [revision objectForKey:@"message"];
                NSString *hash = [revision objectForKey:@"hash_id"];
                NSString *revisionIdentifier = [revision objectForKey:@"revision"];
                NSString *repositoryTitle = nil;
                NSString *repositoryName = nil;
                NSString *repositoryType = nil;

                if (repositoryIdentifier) {
                    // go out and fetch the repository name since we only have its ID
                    NSString *repositoryLookup = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/repositories/%@.json", domain, repositoryIdentifier];
                    NSData *data = [self extraDataWithContentsOfURLRequest:[NSMutableURLRequest requestWithURLString:repositoryLookup username:username password:password]];
                    if (!data) return [NSArray array];
                    
                    NSDictionary *response = [data objectFromJSONData];
                    NSDictionary *repository = [response objectForKey:@"repository"];
                    repositoryTitle = [repository objectForKey:@"title"];
                    repositoryName = [repository objectForKey:@"name"];
                    repositoryType = [repository objectForKey:@"vcs"]; // "git" or svn ("SVN"?)
                }
                
                FeedItem *item = [[FeedItem new] autorelease];
                item.rawDate = date;
                item.published = AutoFormatDate(date);
                item.updated = item.published;
                item.authorIdentifier = [userIdentifier stringValue];
                item.author = [revision objectForKey:@"author"];
                item.content = message;
                item.title = [NSString stringWithFormat:@"%@ committed to %@", item.author, repositoryTitle, message];
                
                if ([repositoryType isEqualToString:@"git"])
                    item.link = [NSURL URLWithString:
                                 [NSString stringWithFormat:@"https://%@.beanstalkapp.com/%@/changesets/%@", domain, repositoryName, hash]];
                else
                    item.link = [NSURL URLWithString:
                                 [NSString stringWithFormat:@"https://%@.beanstalkapp.com/%@/changesets/%@", domain, repositoryName, revisionIdentifier]];
                
                [items addObject:item];
            }
        }
        else if ([request.request.URL.path isEqualToString:@"/api/releases.json"]) {

            NSArray *releases = [data objectFromJSONData];
            
            for (NSDictionary *releaseData in releases) {
                
                NSDictionary *release = [releaseData objectForKey:@"release"];
                NSString *deploymentIdentifier = [release objectForKey:@"id"];
                NSNumber *repositoryIdentifier = [release objectForKey:@"repository_id"];
                NSNumber *userIdentifier = [release objectForKey:@"user_id"];
                NSString *date = [release objectForKey:@"updated_at"];
                NSString *comment = [release objectForKey:@"comment"];
                NSString *environment = [release objectForKey:@"environment_name"];
                NSString *state = [release objectForKey:@"state"];
                NSString *repositoryName = nil;
                NSString *userName = nil;
                
                if (repositoryIdentifier) {
                    // go out and fetch the repository name since we only have its ID
                    NSString *repositoryLookup = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/repositories/%@.json", domain, repositoryIdentifier];
                    NSData *data = [self extraDataWithContentsOfURLRequest:[NSMutableURLRequest requestWithURLString:repositoryLookup username:username password:password]];
                    if (!data) return [NSArray array];
                    
                    NSDictionary *response = [data objectFromJSONData];
                    NSDictionary *repository = [response objectForKey:@"repository"];
                    repositoryName = [repository objectForKey:@"name"];
                }

                if (userIdentifier) {
                    // go out and fetch the user's name since we only have their ID
                    NSString *userLookup = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/users/%@.json", domain, userIdentifier];
                    NSData *data = [self extraDataWithContentsOfURLRequest:[NSMutableURLRequest requestWithURLString:userLookup username:username password:userLookup]];
                    if (!data) return [NSArray array];
                    
                    NSDictionary *response = [data objectFromJSONData];
                    NSDictionary *user = [response objectForKey:@"user"];
                    userName = [NSString stringWithFormat:@"%@ %@", [user objectForKey:@"first_name"], [user objectForKey:@"last_name"]];
                }

                FeedItem *item = [[FeedItem new] autorelease];
                item.rawDate = date;
                item.published = AutoFormatDate(date);
                item.updated = item.published;
                item.authorIdentifier = [userIdentifier stringValue];
                item.author = userName;
                item.title = [NSString stringWithFormat:@"%@ deployed to %@ (%@)", item.author, environment, state, comment];
                item.content = comment;
                item.link = [NSURL URLWithString:
                             [NSString stringWithFormat:@"https://%@.beanstalkapp.com/%@/deployments/%@", domain, repositoryName, deploymentIdentifier]];

                [items addObject:item];
            }
        }
        
        return items;
    }
    else return nil;
}

@end
