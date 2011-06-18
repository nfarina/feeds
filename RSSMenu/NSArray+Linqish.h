
@interface NSArray (Linqish)

// Just like Cocoa's lastObject.
- (id)firstObject;

// Asks this array to collect the result of sending objects from the array to the 'selector' on 'target'.
// The array constructed from all the objects returned is what is passed back. Nil object results are skipped.
- (NSArray *)collect:(SEL)selector on:(id)target;
- (NSArray *)collect:(SEL)selector on:(id)target secondArgument:(id)arg;

// Asks this array to filter the result of sending objects from the array to the 'selector' on 'target'.
// The array constructed from all the objects for which the selector returned true is what is passed back.
- (NSArray *)filter:(SEL)selector on:(id)target;
- (NSArray *)filter:(SEL)selector on:(id)target secondArgument:(id)secondArgument;

// Creates an NSDictionary from this array where the keys are found under the property 'key'.
// If the object has a nil value for its 'key' property, it will be excluded from the dictionary.
- (NSDictionary *)indexedWithKey:(NSString *)key;

// Creates an NSDictionary from this array where the keys are found under the property 'key',
// and the values are NSArrays containing the set of objects with the key in common.
// If the object has a nil value for its 'key' property, it will be excluded from the dictionary.
- (NSDictionary *)groupedWithKey:(NSString *)key;

// Searches this array front to back and returns the first object returning the given value
// for the given selector (determined with isEqual:), or nil if none found.
- (id)firstObjectWithValue:(id)value forSelector:(SEL)selector;

@end
