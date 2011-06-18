#import "NSArray+Linqish.h"

@implementation NSArray (Linqish)

- (id)firstObject {
	return [self count] ? [self objectAtIndex:0] : nil;
}

- (NSArray *)collect:(SEL)selector on:(id)target {
	return [self collect:selector on:target secondArgument:nil];
}

- (NSArray *)collect:(SEL)selector on:(id)target secondArgument:(id)secondArgument {
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.count];
	
	for (id obj in self) {
		id result = [target performSelector:selector withObject:obj withObject:secondArgument];
		if (result) [array addObject:result];
	}
	
	return array;
}

- (NSArray *)filter:(SEL)selector on:(id)target {
	return [self filter:selector on:target secondArgument:nil];
}

- (NSArray *)filter:(SEL)selector on:(id)target secondArgument:(id)secondArgument {
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.count];
	
	for (id obj in self)
		if ([target performSelector:selector withObject:obj withObject:secondArgument]) 
			[array addObject:obj];
	
	return array;
}

- (NSDictionary *)indexedWithKey:(NSString *)key {
	NSMutableDictionary *indexed = [NSMutableDictionary dictionary];
	
	for (id obj in self) {
		id keyValue = [obj valueForKey:key];
		if (keyValue) [indexed setObject:obj forKey:keyValue];
	}
	
	return indexed;
}

- (NSDictionary *)groupedWithKey:(NSString *)key {
	NSMutableDictionary *grouped = [NSMutableDictionary dictionary];
	
	for (id obj in self) {
		id keyValue = [obj valueForKey:key];
		if (keyValue) {
			NSMutableArray *group = [grouped objectForKey:keyValue];
			if (group)
				[group addObject:obj];
			else
				[grouped setObject:[NSMutableArray arrayWithObject:obj] forKey:keyValue];
		}
	}
	
	return grouped;
}

- (id)firstObjectWithValue:(id)value forSelector:(SEL)selector {
	for (id obj in self)
		if ([[obj performSelector:selector] isEqual:value])
			return obj;
	return nil;
}

@end
