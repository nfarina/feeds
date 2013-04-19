
### Overview

SMWebRequest is a very handy lightweight HTTP request class for iOS.

It encapsulates a single HTTP request and response, and is designed to be less verbose
and simpler to use than NSURLConnection. The server response is buffered completely into memory
then passed back to event listeners as NSData. Optionally, you can specify a delegate which
can process the NSData in some way on a background thread then return something else.

More info in the blog post:
http://nfarina.com/post/3776625971/webrequest

### ARC Support

If you are including SMWebRequest in a project that has [Automatic Reference Counting (ARC)](http://clang.llvm.org/docs/AutomaticReferenceCounting.html) enabled, you will need to set the `-fno-objc-arc` compiler flag for our source. To do this in Xcode, go to your active target and select the "Build Phases" tab. In the "Compiler Flags" column, set `-fno-objc-arc` for `SMWebRequest.m`.


