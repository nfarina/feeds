
### Overview

SMXMLDocument is a very handy lightweight XML parser for iOS.

In brief:

    // create a new SMXMLDocument with the contents of sample.xml
    SMXMLDocument *document = [SMXMLDocument documentWithData:data error:&error];

    // Pull out the <books> node
    SMXMLElement *books = [document.root childNamed:@"books"];

    // Look through <books> children of type <book>
    for (SMXMLElement *book in [books childrenNamed:@"book"]) {
      
      // demonstrate common cases of extracting XML data
      NSString *isbn = [book attributeNamed:@"isbn"]; // XML attribute
      NSString *title = [book valueWithPath:@"title"]; // child node value
      
      // show off some KVC magic
      NSArray *authors = [[book childNamed:@"authors"].children valueForKey:@"value"];
      
      // do interesting things...
    }

More info in the blog post:
http://nfarina.com/post/2843708636/a-lightweight-xml-parser-for-ios

### ARC Support

This branch supports (and requires) [Automatic Reference Counting (ARC)](http://clang.llvm.org/docs/AutomaticReferenceCounting.html)
