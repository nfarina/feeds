//
//  NSString+ObjectFromJSONString.m
//  Feeds
//
//  Created by Mark Goody on 17/04/2014.
//  Copyright (c) 2014 Spotlight Mobile. All rights reserved.
//

#import "NSString+ObjectFromJSONString.h"
#import "NSData+ObjectFromJSONData.h"

@implementation NSString (ObjectFromJSONString)

- (id)objectFromJSONString
{
	NSData *jsonData = [self dataUsingEncoding:NSUTF8StringEncoding];

	return [jsonData objectFromJSONData];
}

@end
