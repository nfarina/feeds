//
//  NSData+ObjectFromJSONData.m
//  Feeds
//
//  Created by Mark Goody on 16/04/2014.
//  Copyright (c) 2014 Spotlight Mobile. All rights reserved.
//

#import "NSData+ObjectFromJSONData.h"

@implementation NSData (ObjectFromJSONData)

- (id)objectFromJSONData
{
	NSError *decodingError = nil;
	id object = [NSJSONSerialization JSONObjectWithData:self
												options:NSJSONReadingAllowFragments
												  error:&decodingError];

	if (object == nil && decodingError != nil) {
		NSLog(@"Error decoding JSON data");
	}

	return object;
}

@end
