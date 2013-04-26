#import "BeanstalkAccount.h"

@implementation BeanstalkAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresDomain { return YES; }
+ (NSString *)domainSuffix { return @".beanstalkapp.com"; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
+ (NSTimeInterval)defaultRefreshInterval { return 5*60; } // 5 minutes (via Ilya@Beanstalk)

- (void)validateWithPassword:(NSString *)password {
    
    NSString *URL = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/users/current.json", self.domain];
    
    NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURLString:URL username:self.username password:password];
    URLRequest.HTTPShouldHandleCookies = NO;
    
    self.request = [SMWebRequest requestWithURLRequest:URLRequest delegate:self context:NULL];
    [self.request addTarget:self action:@selector(meRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

- (void)meRequestComplete:(NSData *)data {
    
    NSDictionary *response = [data objectFromJSONData];
    NSDictionary *user = response[@"user"];
    
    NSString *changesets = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/changesets.json", self.domain];
    Feed *changesetsFeed = [Feed feedWithURLString:changesets title:@"Changesets" account:self];
    changesetsFeed.author = user[@"id"]; // store author by unique identifier instead of name
    changesetsFeed.requiresBasicAuth = YES;

    NSString *releases = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/releases.json", self.domain];
    Feed *releasesFeed = [Feed feedWithURLString:releases title:@"Deployments" account:self];
    releasesFeed.author = user[@"id"]; // store author by unique identifier instead of name
    releasesFeed.requiresBasicAuth = YES;

    self.feeds = @[changesetsFeed, releasesFeed];

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
    SMErrorResponse *response = (error.userInfo)[SMErrorResponseKey];
    NSString *message = nil;
    
    if ([(response.response.allHeaderFields)[@"Content-Type"] beginsWithString:@"application/json"]) {
        NSDictionary *data = [response.data objectFromJSONData];
        NSArray *errors = data[@"errors"];
        message = errors.count ? errors[0] : nil;
    }
    
    if (error.code == 500 && message)
        [self.delegate account:self validationDidFailWithMessage:message field:AccountFailingFieldUnknown];
    else if (error.code == 401)
        [self.delegate account:self validationDidFailWithMessage:@"Could not access the given Beanstalk domain. Please check your username and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password {

    NSMutableArray *items = [NSMutableArray array];
        
    if ([request.request.URL.path isEqualToString:@"/api/changesets.json"]) {
        
        NSArray *changesets = [data objectFromJSONData];
        
        for (NSDictionary *changeset in changesets) {
            
            NSDictionary *revision = changeset[@"revision_cache"];
            NSNumber *repositoryIdentifier = revision[@"repository_id"];
            NSNumber *userIdentifier = revision[@"user_id"];
            if ((id)userIdentifier == [NSNull null]) userIdentifier = nil; // this could be null!
            NSString *date = revision[@"time"];
            NSString *message = revision[@"message"];
            NSString *hash = revision[@"hash_id"];
            NSString *revisionIdentifier = revision[@"revision"];
            NSString *repositoryTitle = nil;
            NSString *repositoryName = nil;
            NSString *repositoryType = nil;

            if (repositoryIdentifier) {
                // go out and fetch the repository name since we only have its ID
                NSString *repositoryLookup = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/repositories/%@.json", domain, repositoryIdentifier];
                NSData *data = [self extraDataWithContentsOfURLRequest:[NSMutableURLRequest requestWithURLString:repositoryLookup username:username password:password]];
                if (!data) return nil;
                
                NSDictionary *response = [data objectFromJSONData];
                NSDictionary *repository = response[@"repository"];
                repositoryTitle = repository[@"title"];
                repositoryName = repository[@"name"];
                repositoryType = repository[@"vcs"]; // "git" or svn ("SVN"?)
            }
            
            FeedItem *item = [FeedItem new];
            item.rawDate = date;
            item.published = AutoFormatDate(date);
            item.updated = item.published;
            item.authorIdentifier = [userIdentifier stringValue];
            item.author = revision[@"author"];
            item.content = message;
            item.title = [NSString stringWithFormat:@"%@ committed to %@", item.author, repositoryTitle];
            
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
            
            NSDictionary *release = releaseData[@"release"];
            NSString *deploymentIdentifier = release[@"id"];
            NSNumber *repositoryIdentifier = release[@"repository_id"];
            NSNumber *userIdentifier = release[@"user_id"];
            if ((id)userIdentifier == [NSNull null]) userIdentifier = nil; // this could be null!
            NSString *date = release[@"updated_at"];
            NSString *comment = release[@"comment"];
            NSString *environment = release[@"environment_name"];
            NSString *state = release[@"state"];
            NSString *repositoryName = nil;
            NSString *userName = nil;
            
            if (repositoryIdentifier) {
                // go out and fetch the repository name since we only have its ID
                NSString *repositoryLookup = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/repositories/%@.json", domain, repositoryIdentifier];
                NSData *data = [self extraDataWithContentsOfURLRequest:[NSMutableURLRequest requestWithURLString:repositoryLookup username:username password:password]];
                if (!data) return nil;
                
                NSDictionary *response = [data objectFromJSONData];
                NSDictionary *repository = response[@"repository"];
                repositoryName = repository[@"name"];
            }

            if (userIdentifier) {
                // go out and fetch the user's name since we only have their ID
                NSString *userLookup = [NSString stringWithFormat:@"https://%@.beanstalkapp.com/api/users/%@.json", domain, userIdentifier];
                NSData *data = [self extraDataWithContentsOfURLRequest:[NSMutableURLRequest requestWithURLString:userLookup username:username password:userLookup]];
                if (!data) return nil;
                
                NSDictionary *response = [data objectFromJSONData];
                NSDictionary *user = response[@"user"];
                userName = [NSString stringWithFormat:@"%@ %@", user[@"first_name"], user[@"last_name"]];
            }

            FeedItem *item = [FeedItem new];
            item.rawDate = date;
            item.published = AutoFormatDate(date);
            item.updated = item.published;
            item.authorIdentifier = [userIdentifier stringValue];
            item.author = userName;
            item.title = [NSString stringWithFormat:@"%@ deployed to %@ (%@)", item.author, environment, state];
            item.content = comment;
            item.link = [NSURL URLWithString:
                         [NSString stringWithFormat:@"https://%@.beanstalkapp.com/%@/deployments/%@", domain, repositoryName, deploymentIdentifier]];

            [items addObject:item];
        }
    }
    
    return items;
}

@end
