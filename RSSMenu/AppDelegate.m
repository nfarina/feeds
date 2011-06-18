#import "AppDelegate.h"
#import "RSSFeed.h"

@interface AppDelegate ()
@property (nonatomic, copy) NSArray *feeds;
- (void)refreshFeeds;
@end

@implementation AppDelegate
@synthesize menu, feeds;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
	statusItem.menu = menu;
    
    [statusItem setHighlightMode:YES];
	[statusItem setImage:[NSImage imageNamed:@"StatusItem.png"]];
	[statusItem setAlternateImage:[NSImage imageNamed:@"StatusItemSelected.png"]];
	[statusItem setEnabled:YES];

    NSArray *feedDicts = [[NSUserDefaults standardUserDefaults] arrayForKey:@"feeds"];
    
    if (!feedDicts) {
        feedDicts = [NSArray arrayWithObject:[NSDictionary dictionaryWithObject:@"http://dribbble.com/shots/popular.rss" forKey:@"url"]];
        [[NSUserDefaults standardUserDefaults] setObject:feedDicts forKey:@"feeds"];
    }
    
    self.feeds = [feedDicts collect:@selector(feedWithDictionary:) on:[RSSFeed class]];
    
    for (RSSFeed *feed in feeds)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kRSSFeedUpdatedNotification object:feed];
    
    [self refreshFeeds];
}

- (void)refreshFeeds {
    [feeds makeObjectsPerformSelector:@selector(refresh)];
}

- (void)feedUpdated:(NSNotification *)notification {

    RSSFeed *feed = [notification object];
    
    while (![[menu itemAtIndex:0] isSeparatorItem])
        [menu removeItemAtIndex:0];
    
    for (RSSItem *item in [feed.items reverseObjectEnumerator]) {
        [menu insertItemWithTitle:item.title action:NULL keyEquivalent:@"" atIndex:0];
    }
}

@end
