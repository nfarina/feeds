#import "SMWebRequest.h"

//
// Utility class for tracking our target/action pairs.
//

@interface SMTargetAction : NSObject {
@package
    id target;
    SEL action;
    SMWebRequestEvents events;
}
@end
@implementation SMTargetAction
@end

//
// WebRequest.
//

NSString *const kSMWebRequestComplete = @"SMWebRequestComplete", *const kSMWebRequestError = @"SMWebRequestError";
NSString *const SMErrorResponseKey = @"response";

@interface SMWebRequest ()
@property (nonatomic, assign) id<SMWebRequestDelegate> delegate;
@property (nonatomic, retain) id context;
@property (nonatomic, retain) NSMutableArray *targetActions;
@property (nonatomic, retain) NSMutableData *data;
@property (nonatomic, retain) NSURLRequest *request;
@property (nonatomic, retain) NSURLResponse *response;
@property (nonatomic, retain) NSURLConnection *connection;
@end

@implementation SMWebRequest
@synthesize context, targetActions, delegate, data, request, response, connection;

- (id)initWithURLRequest:(NSURLRequest *)theRequest delegate:(id<SMWebRequestDelegate>)theDelegate context:(id)theContext {
    self = [super init];
    if (self) {
        self.request = theRequest;
        self.delegate = theDelegate;
        self.context = theContext;
        self.targetActions = [NSMutableArray array]; 
    }
    return self;
}

- (void)dealloc {
    //NSLog(@"Dealloc %@", self);
    [self cancel];
    self.delegate = nil;
    self.context = nil;
    self.request = nil;
    self.response = nil;
    self.data = nil;
    self.connection = nil;
    self.targetActions = nil;
    [super dealloc];
}

+ (SMWebRequest *)requestWithURL:(NSURL *)theURL {
    return [SMWebRequest requestWithURL:theURL delegate:nil context:nil];
}

+ (SMWebRequest *)requestWithURL:(NSURL *)theURL delegate:(id<SMWebRequestDelegate>)theDelegate context:(id)theContext {
    return [SMWebRequest requestWithURLRequest:[NSURLRequest requestWithURL:theURL] delegate:theDelegate context:theContext];
}

+ (SMWebRequest *)requestWithURLRequest:(NSURLRequest *)theRequest delegate:(id<SMWebRequestDelegate>)theDelegate context:(id)theContext {
    return [[[SMWebRequest alloc] initWithURLRequest:theRequest delegate:theDelegate context:theContext] autorelease];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@>", self.request.URL];
}

- (void)start {
    if (requestFlags.started) return; // subsequent calls to this method won't do anything
    
    requestFlags.started = YES;
    
    //NSLog(@"Requesting %@", self);

    self.data = [NSMutableData data];
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
}

- (BOOL)started { return requestFlags.started; }

- (void)cancel {
    if (requestFlags.cancelled) return; // subsequent calls to this method won't do anything
    
    // the only thing that can actually be "cancelled" is the NSURLConnection. Background thread processing can't be
    // cancelled since the background thread must run to completion or else you end up with god knows what on the heap.
    if (connection) {
        //NSLog(@"Cancelling %@", self);
        [connection cancel];
        self.connection = nil;
    }
    requestFlags.cancelled = YES;
    self.context = nil; // you'll never hear from us again.
}

#pragma mark Target/Action management

- (SMTargetAction *)targetActionForTarget:(id)target action:(SEL)action {
    for(SMTargetAction *ta in targetActions)
        if (ta->target == target && (ta->action == action || !action))
            return ta;
    
    return nil;
}

- (void)addTarget:(id)target action:(SEL)action forRequestEvents:(SMWebRequestEvents)events {
    
    SMTargetAction *ta = [self targetActionForTarget:target action:action];
    
    if (!ta) {
        ta = [[[SMTargetAction alloc] init] autorelease];
        ta->target = target;
        ta->action = action;
        [targetActions addObject:ta];
    }
    
    ta->events |= events;
}

- (void)removeTarget:(id)target action:(SEL)action forRequestEvents:(SMWebRequestEvents)events {
    
    while (true) { // if you passed NULL for the action, we may have to search multiple times
        
        SMTargetAction *ta = [self targetActionForTarget:target action:action];
        
        if (!ta) break;
        
        SMWebRequestEvents toRemove = ta->events & events;
        ta->events -= toRemove;
        
        if (!ta->events)
            [targetActions removeObject:ta];        
    }
    
    if (![targetActions count])
        [self cancel];
}

- (void)removeTarget:(id)target {
    [self removeTarget:target action:NULL forRequestEvents:SMWebRequestEventAllEvents];
}

- (NSMutableArray *)targetActionsForEvents:(SMWebRequestEvents)events {
    NSMutableArray *resultTargetActions = [NSMutableArray array];
    
    for(SMTargetAction *ta in targetActions)
        if ((ta->events & events) != 0) [resultTargetActions addObject:ta];
    
    return resultTargetActions;
}

// only call on main thread
- (void)dispatchEvents:(SMWebRequestEvents)events withArgument:(id)arg {
    
    for (SMTargetAction *ta in [self targetActionsForEvents:events])
        [ta->target performSelector:ta->action withObject:arg withObject:context];
    
    // events dispatched (if any) and delegate called (if any); so we're done.
    self.context = nil;
}

- (void)dispatchComplete:(id)resultObject {
    
    // notify the delegate first
    if ([delegate respondsToSelector:@selector(webRequest:didCompleteWithResult:context:)])
        [delegate webRequest:self didCompleteWithResult:resultObject context:context];      
    
    // notify event listeners
    [self dispatchEvents:SMWebRequestEventComplete withArgument:resultObject];
    
    // notify the world last
    [[NSNotificationCenter defaultCenter] postNotificationName:kSMWebRequestComplete object:self];
}

- (void)dispatchError:(NSError *)error {
    
    // notify the delegate first
    if ([delegate respondsToSelector:@selector(webRequest:didFailWithError:context:)])
        [delegate webRequest:self didFailWithError:error context:context];
    
    // notify event listeners
    [self dispatchEvents:SMWebRequestEventError withArgument:error];
    
    // notify the world last
    NSDictionary *info = [NSDictionary dictionaryWithObject:error forKey:NSUnderlyingErrorKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:kSMWebRequestError object:self userInfo:info];
}

// in a background thread! don't touch our instance members!
- (void)processDataInBackground:(NSData *)theData {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    id resultObject = theData;
    
    if ([delegate respondsToSelector:@selector(webRequest:resultObjectForData:context:)])
        resultObject = [delegate webRequest:self resultObjectForData:theData context:context];
    
    [self performSelectorOnMainThread:@selector(backgroundProcessingComplete:) withObject:resultObject waitUntilDone:NO];
    [pool release];
}

// back on the main thread
- (void)backgroundProcessingComplete:(id)resultObject {
    if (!requestFlags.cancelled)
		[self dispatchComplete:resultObject];
	[delegate release];
	[self release];
}

#pragma mark NSURLConnection delegate methods

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)newRequest redirectResponse:(NSURLResponse *)redirectResponse {
    if (redirectResponse && [(NSHTTPURLResponse *)redirectResponse statusCode] != 301)
        requestFlags.wasTemporarilyRedirected = YES;
    
    // see if our delegate cares about this
    if ([delegate respondsToSelector:@selector(webRequest:willSendRequest:redirectResponse:)])
        return [delegate webRequest:self willSendRequest:newRequest redirectResponse:redirectResponse];
    else
        return newRequest; // let it happen
}

- (void)connection:(NSURLConnection *)conn didReceiveResponse:(NSURLResponse *)aResponse {
    self.response = aResponse;
    [data setLength:0];
}

- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)moreData {
    [data appendData:moreData];
}

- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error {
    NSLog(@"SMWebRequest's NSURLConnection failed! Error - %@ %@", error, conn);
    
    self.connection = nil;
    self.data = nil;
    [self retain]; // we must retain ourself before we call handlers, in case they release us!
    
    [self dispatchError:error];
    
    [self release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn {
    
    //NSLog(@"Finished loading %@", self);
    
    [self retain]; // we must retain ourself before we call handlers, in case they release us!
    
    NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 200;
    
    if (conn && response && status >= 400) {
        NSLog(@"Failed with HTTP status code %i while loading %@", (int)status, self);
        
        SMErrorResponse *error = [[[SMErrorResponse alloc] init] autorelease];
        error.response = (NSHTTPURLResponse *)response;
        error.data = data;
        
        NSMutableDictionary* details = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        @"Received an HTTP status code indicating failure.", NSLocalizedDescriptionKey,
                                        error, SMErrorResponseKey,
                                        nil];
        [self dispatchError:[NSError errorWithDomain:@"SMWebRequest" code:status userInfo:details]];
    }
    else {
        if ([delegate respondsToSelector:@selector(webRequest:resultObjectForData:context:)]) {
            
            // neither us nor our delegate can get dealloced whilst processing on the background
            // thread or else the background thread could try to do stuff with pointers to garbage.
            // thus we need have a mechanism for keeping ourselves alive during the background
            // processing.
            [self retain];
            [delegate retain];
            
            [self performSelectorInBackground:@selector(processDataInBackground:) withObject:data];
        }
        else
            [self dispatchComplete:data];
    }
    
    self.connection = nil;
    self.data = nil; // don't keep this!
    [self release];
}

@end

@implementation SMErrorResponse
@synthesize response, data;
- (void)dealloc {
    self.response = nil;
    self.data = nil;
    [super dealloc];
}
@end