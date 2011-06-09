#import "AppDelegate.h"
#import "RSSItem.h"

@interface AppDelegate ()
@end

@implementation AppDelegate
@synthesize menu;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
	statusItem.menu = menu;
    
    [statusItem setHighlightMode:YES];
	[statusItem setImage:[NSImage imageNamed:@"StatusItem.png"]];
	[statusItem setAlternateImage:[NSImage imageNamed:@"StatusItemSelected.png"]];
	[statusItem setEnabled:YES];
    
    NSURL *url = [NSURL URLWithString:@"http://news.ycombinator.com/rss"];
    
    SMWebRequest *request = [RSSItem requestForItemsWithURL:url];
    [request addTarget:self action:@selector(requestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [request start];
}

- (void)requestComplete:(NSArray *)theItems {
    
    for (RSSItem *item in [theItems reverseObjectEnumerator]) {
        [menu insertItemWithTitle:item.title action:NULL keyEquivalent:@"" atIndex:0];
    }
}

@end
