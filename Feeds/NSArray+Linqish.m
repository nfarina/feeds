#import "NSArray+Linqish.h"

@implementation NSArray (Linqish)

#if NS_BLOCKS_AVAILABLE

- (NSArray *)selectUsingBlock:(id (^)(id obj))block {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.count];
	
	for (id obj in self) {
        id result = block(obj);
		if (result) [array addObject:result];
	}
	
	return array;
}

- (id)aggregateUsingBlock:(id (^)(id accumulator, id obj))block {
    
    id result = nil;
	
	NSEnumerator *enumerator = [self objectEnumerator];
	id firstObject = [enumerator nextObject];
	
	if (firstObject) {
		result = firstObject;
		id secondObject;
		
		while (secondObject = [enumerator nextObject])
			result = block(result, secondObject);
	}
	
	return result;
}

#endif

// We need to disable this warning because of our use of performSelector, instead we assume that
// the selector you give us returns an autoreleased object.
// See http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

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
	for (id obj in self) {
        id objValue = [obj performSelector:selector];
		if ((!objValue && !value) || [objValue isEqual:value]) // make sure to allow both nil
			return obj;
    }
	return nil;
}

#pragma clang diagnostic pop

@end
