#import "AppDelegate.h"
#import "RSSFeed.h"

#define MAX_ITEMS 30

@interface AppDelegate ()
@property (nonatomic, copy) NSArray *feeds;
@property (nonatomic, retain) NSTimer *refreshTimer;
- (void)refreshFeeds;
- (void)openBrowserWithURL:(NSURL *)url;
@end

@implementation AppDelegate
@synthesize menu, feeds, refreshTimer;

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
    
    allItems = [NSMutableArray new];
    self.feeds = [feedDicts collect:@selector(feedWithDictionary:) on:[RSSFeed class]];
    
    for (RSSFeed *feed in feeds)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kRSSFeedUpdatedNotification object:feed];
    
    refreshTimer = [NSTimer timerWithTimeInterval:60*5 target:self selector:@selector(refreshFeeds) userInfo:nil repeats:YES];
    [self refreshFeeds]; // start now
}

- (void)refreshFeeds {
    [feeds makeObjectsPerformSelector:@selector(refresh)];
}

- (void)feedUpdated:(NSNotification *)notification {

    //RSSFeed *feed = [notification object];
    
    while (![[menu itemAtIndex:0] isSeparatorItem])
        [menu removeItemAtIndex:0];
    
    // build combined feed
    [allItems removeAllObjects];
    
    for (RSSFeed *feed in feeds)
        [allItems addObjectsFromArray:feed.items];
    
    [allItems sortUsingSelector:@selector(compareItemByPublishedDate:)];

    for (int i=0; i<[allItems count] && i<MAX_ITEMS; i++) {
        
        RSSItem *item = [allItems objectAtIndex:i];
        
        NSString *title = item.title;
        if ([title length] > 50)
            title = [[title substringToIndex:50] stringByAppendingString:@"…"];

        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(itemSelected:) keyEquivalent:@""];
        [menuItem setTag:i];
        
        [menu insertItem:menuItem atIndex:i];
    }
}

- (void)itemSelected:(NSMenuItem *)menuItem {
    
    RSSItem *item = [allItems objectAtIndex:menuItem.tag];
    [self openBrowserWithURL:item.link];
}

- (void)openBrowserWithURL:(NSURL *)url {
	
	NSString *bundlePath = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultBrowser"];
	if ([bundlePath length]) {
		NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
		[[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url] withAppBundleIdentifier:[bundle bundleIdentifier] options:0 additionalEventParamDescriptor:nil launchIdentifiers:NULL];
	}
	else
		[[NSWorkspace sharedWorkspace] openURL:url];
}

@end
