//
//  NSDictionary+JSONString.m
//  Feeds
//
//  Created by Mark Goody on 17/04/2014.
//  Copyright (c) 2014 Spotlight Mobile. All rights reserved.
//

#import "NSDictionary+JSONString.h"

@implementation NSDictionary (JSONString)

- (NSString *)JSONString
{
	NSError *encodingError = nil;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self
													   options:0
														 error:&encodingError];

	if (jsonData == nil && encodingError != nil) {
		NSLog(@"Error encoding JSON data for dictionary: %@", encodingError.localizedDescription);
	}

	NSString *jsonString = nil;
	if (jsonData != nil) {
		jsonString = [[NSString alloc] initWithBytes:jsonData.bytes
											  length:jsonData.length
											encoding:NSUTF8StringEncoding];
	}

	return jsonString;
}

@end
