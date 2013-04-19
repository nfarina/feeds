/*
 The MIT License
 
 Copyright (c) 2010 Nick Farina
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE. 
 */

/*
 
 SMWebRequest
 ------------
 Created by Nick Farina (nfarina@gmail.com) and Benjamin van der Veen (b@bvanderveen.com)
 Version 1.0
 
 */

// SMWebRequest encapsulates a single HTTP request and response. It is designed to be less verbose
// and simpler to use than NSURLConnection. The server response is buffered completely into memory
// then passed back to event listeners as NSData. Optionally, you can specify a delegate which
// can process the NSData in some way on a background thread then return something else.

// While the SMWebRequest's internal connection to the server is open, it will retain itself.
// This means you can create an autoreleased SMWebRequest without retaining it and subscribe
// to its events for a quick and dirty (non-cancellable) request.

// Please note that this means you MUST remove any event listeners before releasing
// your SMWebRequest! Otherwise the request may still be alive and will attempt to execute
// events on your object (which may be dealloc'd at this point).

enum {
    SMWebRequestEventComplete  = 1 << 0, // selector will be passed the result pointer
    SMWebRequestEventError     = 1 << 1, // selector will be passed a pointer to NSError instance
    SMWebRequestEventAllEvents = 0xFFFFFFFF
};
typedef NSUInteger SMWebRequestEvents;

@protocol SMWebRequestDelegate;

@interface SMWebRequest : NSObject
#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_4_3
<NSURLConnectionDelegate> 
#else
<NSURLConnectionDataDelegate>
#endif
{
    id<SMWebRequestDelegate> delegate; // not retained
    id context;
    
    NSMutableArray *targetActions;
    NSURLConnection *connection;
    NSURLRequest *request;
    NSURLResponse *response;
    NSMutableData *data;
    struct {
        unsigned int started:1;
        unsigned int cancelled:1;
        unsigned int wasTemporarilyRedirected:1;
    } requestFlags;
}

@property (nonatomic, readonly) BOOL started;
@property (nonatomic, readonly, retain) id context;

@property (nonatomic, readonly, retain) NSURLRequest *request;
@property (nonatomic, readonly, retain) NSURLResponse *response;

// Designated initializer.
- (id)initWithURLRequest:(NSURLRequest *)request delegate:(id<SMWebRequestDelegate>)delegate context:(id)context;

// Convenience creators.
+ (SMWebRequest *)requestWithURL:(NSURL *)url;
+ (SMWebRequest *)requestWithURL:(NSURL *)url delegate:(id<SMWebRequestDelegate>)delegate context:(id)context;
+ (SMWebRequest *)requestWithURLRequest:(NSURLRequest *)request delegate:(id<SMWebRequestDelegate>)delegate context:(id)context;

- (void)start;
- (void)cancel;

// register interest. does not retain target. action can take one or two arguments; 
// first is the result object returned by the delegate, second is the context.
- (void)addTarget:(id)target action:(SEL)action forRequestEvents:(SMWebRequestEvents)event;

// pass in NULL for the action to remove all actions for that target.
// if there are no more target/actions, loading/processing will be cancelled.
- (void)removeTarget:(id)target action:(SEL)action forRequestEvents:(SMWebRequestEvents)event;
- (void)removeTarget:(id)target; // all actions+events

@end

@protocol SMWebRequestDelegate <NSObject>
@optional

// called on the main thread if applicable, behaves just like NSURLConnection.
- (NSURLRequest *)webRequest:(SMWebRequest *)webRequest willSendRequest:(NSURLRequest *)newRequest redirectResponse:(NSURLResponse *)redirectResponse;

// called on a background thread and result will be passed to the targets, 
// otherwise if the delegate is nil the data will be passed to the targets.
- (id)webRequest:(SMWebRequest *)webRequest resultObjectForData:(NSData *)data context:(id)context;

// both of these are called on the main thread, BEFORE the target/action listeners are called
- (void)webRequest:(SMWebRequest *)webRequest didCompleteWithResult:(id)result context:(id)context;
- (void)webRequest:(SMWebRequest *)webRequest didFailWithError:(NSError *)error context:(id)context;

@end

// Global NSNotifications you can hook into to be notified of request completions and errors.
extern NSString *const kSMWebRequestComplete, *const kSMWebRequestError;

// For NSErrors generated by SMWebRequest, you can use this key to retrieve the HTTP response plus the
// raw response data from the server (if any), which may contain useful information about the error.
extern NSString *const SMErrorResponseKey; // SMErrorResponse

// Special wrapper class for passing back information about a response+data inside an NSError.
// always associated with SMErrorResponseKey.
@interface SMErrorResponse : NSObject {
    NSHTTPURLResponse *response;
    NSData *data;
}
@property (nonatomic, retain) NSHTTPURLResponse *response;
@property (nonatomic, retain) NSData *data;
@end
