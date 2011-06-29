#import "AppDelegate.h"
#import "Feed.h"
#import "HotKeys.h"

#define MAX_ITEMS 30
#define MAX_GROWLS 3
#define CHECK_INTERVAL 60*1

@interface AppDelegate ()
@property (nonatomic, copy) NSArray *feeds;
@property (nonatomic, retain) NSTimer *refreshTimer;
- (void)reachabilityChanged;
- (void)refreshFeeds;
- (void)openBrowserWithURL:(NSURL *)url;
- (void)updateStatusItemIcon;
@end

@implementation AppDelegate
@synthesize feeds, refreshTimer;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    // show the dock icon immediately if necessary
#if DEBUG
    ProcessSerialNumber psn = { 0, kCurrentProcess }; 
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
#endif

    [GrowlApplicationBridge setGrowlDelegate:self];

    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
	statusItem.menu = menu;

    statusItemView = [[StatusItemView alloc] initWithStatusItem:statusItem];

    //[statusItem setHighlightMode:YES];
	//[statusItem setImage:[NSImage imageNamed:@"StatusItem.png"]];
	//[statusItem setAlternateImage:[NSImage imageNamed:@"StatusItemSelected.png"]];
	[statusItem setEnabled:YES];
    [statusItem setView:statusItemView];

    // register hot key for popping open the menu
    [HotKeys registerHotKeys];
    
    NSArray *feedDicts = [[NSUserDefaults standardUserDefaults] arrayForKey:@"feeds"];
    
    if (!feedDicts) {
        feedDicts = [NSArray arrayWithObject:[NSDictionary dictionaryWithObject:@"http://dribbble.com/shots/popular.rss" forKey:@"url"]];
        [[NSUserDefaults standardUserDefaults] setObject:feedDicts forKey:@"feeds"];
    }
    
    allItems = [NSMutableArray new];
    self.feeds = [feedDicts collect:@selector(feedWithDictionary:) on:[Feed class]];
    
    reachability = [[Reachability reachabilityForInternetConnection] retain];
	[reachability startNotifier];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kFeedUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedFailed:) name:kSMWebRequestError object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged) name:kReachabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openMenuHotkeyPressed) name:kHotKeyManagerOpenMenuNotification object:nil];
    
    [self reachabilityChanged];
    
#if DEBUG
    [self openPreferences:nil];
#endif
}

- (void)setRefreshTimer:(NSTimer *)value {
    [refreshTimer invalidate];
    refreshTimer = [value retain];
}

- (void)refreshFeeds {
    //NSLog(@"Refreshing feeds...");
    [feeds makeObjectsPerformSelector:@selector(refresh)];
}

- (void)updateStatusItemIcon {
    if (refreshTimer) {

        for (FeedItem *item in allItems)
            if (!item.viewed) {
                // you've got stuff up there that you haven't seen in the menu, so glow the icon to let you know!
                //[statusItem setImage:[NSImage imageNamed:@"StatusItemUnread.png"]];
                return;
            }

        // default
        //[statusItem setImage:[NSImage imageNamed:@"StatusItem.png"]];
    }
    else // we're not running. 
    {}//[statusItem setImage:[NSImage imageNamed:@"StatusItemInactive.png"]];
}

- (void)reachabilityChanged {

    if ([reachability currentReachabilityStatus] != NotReachable) {
        
        NSLog(@"Internet is reachable. Refreshing and resetting timer.");
        
        [self refreshFeeds];
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:CHECK_INTERVAL target:self selector:@selector(refreshFeeds) userInfo:nil repeats:YES];
    }
    else {
        NSLog(@"Internet is NOT reachable. Killing timer.");
        self.refreshTimer = nil;
    }
    
    [self updateStatusItemIcon];
}

- (void)feedFailed:(NSNotification *)notification {
    
    NSError *error = [[notification userInfo] objectForKey:NSUnderlyingErrorKey];
    SMWebRequest *request = [notification object];
    
    if ([[error domain] isEqual:(id)kCFErrorDomainCFNetwork]) {
        NSLog(@"Network error while fetching feed: %@", request);
    }
    else {
        NSLog(@"Failed with HTTP status code %i while fetching feed: %@", (int)[error code], request);
    }
}

- (void)feedUpdated:(NSNotification *)notification {

    Feed *feed = [notification object];
    
    while (![[menu itemAtIndex:0] isSeparatorItem])
        [menu removeItemAtIndex:0];
    
    // build combined feed
    [allItems removeAllObjects];
    
    for (Feed *feed in feeds)
        [allItems addObjectsFromArray:feed.items];
    
    [allItems sortUsingSelector:@selector(compareItemByPublishedDate:)];
    int notifications = 0;
    
    for (int i=0; i<[allItems count] && i<MAX_ITEMS; i++) {
        
        FeedItem *item = [allItems objectAtIndex:i];
        
        NSString *title = item.title;
        if ([title length] > 45)
            title = [[title substringToIndex:45] stringByAppendingString:@"…"];
        
        NSString *content = item.strippedContent;
        if ([content length] > 60)
            content = [[content substringToIndex:60] stringByAppendingString:@"…"];

        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(itemSelected:) keyEquivalent:@""];
        [menuItem setTag:i];
        
        [menu insertItem:menuItem atIndex:i];
        
        if (!item.notified && notifications++ < MAX_GROWLS) {
            [GrowlApplicationBridge
             notifyWithTitle:title
             description:content
             notificationName:@"NewItem"
             iconData:nil
             priority:(signed int)0
             isSticky:FALSE
             clickContext:[item.link absoluteString]];
        }
    }
    
    // mark all as notified
    for (FeedItem *item in feed.items)
        item.notified = YES;
    
    [self updateStatusItemIcon];
}

- (void)openMenuHotkeyPressed {
    [statusItem popUpStatusItemMenu:menu];
}

- (void)menuDidClose:(NSMenu *)menu {
    for (FeedItem *item in allItems)
        item.viewed = YES;
    
    [self updateStatusItemIcon];
}

- (void)itemSelected:(NSMenuItem *)menuItem {
    
    FeedItem *item = [allItems objectAtIndex:menuItem.tag];
    [self openBrowserWithURL:item.link];
}

- (void)growlNotificationWasClicked:(NSString *)URLString {
    if (URLString)
        [self openBrowserWithURL:[NSURL URLWithString:URLString]];
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

- (IBAction)openPreferences:(id)sender {

    if (!preferencesController)
        preferencesController = [[PreferencesController alloc] initPreferencesController];

	[preferencesController showPreferences];
}

@end
