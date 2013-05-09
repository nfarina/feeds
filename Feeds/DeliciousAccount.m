//
//  DeliciousAccount.m
//  Feeds
//
//  Created by Tobias Tom on 09.05.13.
//  Copyright (c) 2013 Tobias Tom. All rights reserved.
//

#import "DeliciousAccount.h"

@implementation DeliciousAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresUsername { return YES; }

- (void)validateWithPassword:(NSString *)password {
    NSString *URL = [NSString stringWithFormat:@"http://feeds.delicious.com/v2/rss/network/%@", self.username];
    
    self.request = [SMWebRequest requestWithURL:[NSURL URLWithString:URL] delegate:nil context:NULL];
    [self.request addTarget:self
                     action:@selector(authorizationSuccessful:password:)
           forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self
                     action:@selector(authorizationFailedWithError:)
           forRequestEvents:SMWebRequestEventError];

    [self.request start];
}


- (void)authorizationSuccessful:(NSData *)data password:(NSString *)password {
    self.feeds = @[[Feed feedWithURLString:[NSString stringWithFormat:@"http://feeds.delicious.com/v2/rss/network/%@", self.username]
                                     title:@"Network"
                                   account:self]];
    
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

- (void)authorizationFailedWithError:(NSError *)error {
    if ( error.code == 401 ) {
        [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given delicious account. Please check your username and password." field:0];
    } else {
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
    }
}

@end
