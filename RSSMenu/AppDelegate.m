#import "AppDelegate.h"
#import "Feed.h"
#import "HotKeys.h"
#import "FeedItemView.h"
#import "StatusItemView.h"

#define MAX_ITEMS 30
#define MAX_GROWLS 3
#define CHECK_INTERVAL 60*1

@interface AppDelegate ()
@property (nonatomic, retain) NSTimer *refreshTimer;
- (NSArray *)allFeeds;
- (void)accountsChanged:(NSNotification *)notification;
- (void)reachabilityChanged;
- (void)refreshFeeds;
- (void)openBrowserWithURL:(NSURL *)url;
- (void)updateStatusItemIcon;
- (void)rebuildItems;
@end

@implementation AppDelegate
@synthesize refreshTimer;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    // show the dock icon immediately if necessary
#if DEBUG
//    ProcessSerialNumber psn = { 0, kCurrentProcess }; 
//    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
#endif

    [GrowlApplicationBridge setGrowlDelegate:self];

    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
	statusItem.menu = menu;

    statusItemView = [[StatusItemView alloc] initWithStatusItem:statusItem];

//  [statusItem setHighlightMode:YES];
//	[statusItem setImage:[NSImage imageNamed:@"StatusItem.png"]];
//	[statusItem setAlternateImage:[NSImage imageNamed:@"StatusItemSelected.png"]];
    [statusItem setEnabled:YES];
    [statusItem setView:statusItemView];

    popover = [[NSPopover alloc] init];
    popover.contentViewController = [[[NSViewController alloc] init] autorelease];
    popover.contentViewController.view = [[[WebView alloc] initWithFrame:NSMakeRect(0, 0, 415, 500)] autorelease];
    popover.animates = NO;

    shimItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
    shimItem.view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)] autorelease];
    [menu addItem:shimItem];

    // register hot key for popping open the menu
    [HotKeys registerHotKeys];
    
    allItems = [NSMutableArray new];
    
//    NSArray *feedDicts = [[NSUserDefaults standardUserDefaults] arrayForKey:@"feeds"];
//    
//    if (!feedDicts) {
//        feedDicts = [NSArray arrayWithObject:[NSDictionary dictionaryWithObject:@"http://dribbble.com/shots/popular.rss" forKey:@"url"]];
//        [[NSUserDefaults standardUserDefaults] setObject:feedDicts forKey:@"feeds"];
//    }
//    
//    self.feeds = [feedDicts collect:@selector(feedWithDictionary:) on:[Feed class]];
    
    reachability = [[Reachability reachabilityForInternetConnection] retain];
	[reachability startNotifier];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountsChanged:) name:kAccountsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kFeedUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedFailed:) name:kSMWebRequestError object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged) name:kReachabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openMenuHotkeyPressed) name:kHotKeyManagerOpenMenuNotification object:nil];
    
    [self reachabilityChanged];
    
#if DEBUG
//    [self openPreferences:nil];
#endif

    [self accountsChanged:nil];
}

- (void)setRefreshTimer:(NSTimer *)value {
    [refreshTimer invalidate];
    refreshTimer = [value retain];
}

- (NSArray *)allFeeds {
    NSMutableArray *feeds = [NSMutableArray array];
    for (Account *account in [Account allAccounts]) [feeds addObjectsFromArray:account.feeds];
    return feeds;
}

- (void)accountsChanged:(NSNotification *)notification {
    [self rebuildItems];
    [self refreshFeeds];
}

- (void)refreshFeeds {
    //NSLog(@"Refreshing feeds...");
    [[self allFeeds] makeObjectsPerformSelector:@selector(refresh)];
}

- (void)updateStatusItemIcon {
    if (refreshTimer) {

        for (FeedItem *item in allItems)
            if (!item.viewed) {
                // you've got stuff up there that you haven't seen in the menu, so glow the icon to let you know!
                statusItemView.icon = StatusItemIconUnread;
                return;
            }

        // default
        statusItemView.icon = StatusItemIconNormal;
    }
    else // we're not running. 
        statusItemView.icon = StatusItemIconInactive;
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
    [self rebuildItems];

    Feed *feed = [notification object];
    int notifications = 0;
    
    for (int i=0; i<[allItems count] && i<MAX_ITEMS; i++) {
        
        FeedItem *item = [allItems objectAtIndex:i];
        
        if (!item.notified && notifications++ < MAX_GROWLS) {
            [GrowlApplicationBridge
             notifyWithTitle:[item.title truncatedAfterIndex:45]
             description:[[item.content stringByFlatteningHTML] truncatedAfterIndex:45]
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

- (void)rebuildItems {
    
    [allItems removeAllObjects];
    
    for (Feed *feed in self.allFeeds)
        [allItems addObjectsFromArray:feed.items];
    
    [allItems sortUsingSelector:@selector(compareItemByPublishedDate:)];
    
    while (![menu itemAtIndex:0].isSeparatorItem)
        [menu removeItemAtIndex:0];

    for (int i=0; i<allItems.count && i<MAX_ITEMS; i++) {
        
        FeedItem *item = [allItems objectAtIndex:i];
        
        NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:[item.title truncatedAfterIndex:45] action:@selector(itemSelected:) keyEquivalent:@""] autorelease];
        menuItem.tag = i+1;

        [menu insertItem:menuItem atIndex:i];
    }
    
    if ([allItems count] == 0) {
        NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"No Items" action:NULL keyEquivalent:@""] autorelease];
        [menu insertItem:menuItem atIndex:0];
    }
}

- (void)openMenuHotkeyPressed {
    [statusItemView toggleMenu];
}

- (void)menu:(NSMenu *)theMenu willHighlightItem:(NSMenuItem *)menuItem {
    
    if (menuItem.tag > 0) {

        //NSLog(@"Found shim view at %@", NSStringFromPoint([[shimItem view] convertPointToBase:[shimItem.view frame].origin]));
        
        FeedItem *item = [allItems objectAtIndex:menuItem.tag-1];
        
        WebView *webView = (WebView *)popover.contentViewController.view;
        [webView.mainFrame loadHTMLString:item.content baseURL:nil];
        
        NSRect frame = shimItem.view.superview.frame;
        
        NSInteger shimIndex = [menu indexOfItem:shimItem];
        NSInteger itemIndex = [menu indexOfItem:menuItem];
        
        frame.origin.y += 3 + (19 * (shimIndex-itemIndex-1));
        [popover showRelativeToRect:frame ofView:shimItem.view.superview.superview preferredEdge:NSMinXEdge];
    }
    else {
        [popover close];
    }
}

- (void)menuDidClose:(NSMenu *)menu {
    for (FeedItem *item in allItems)
        item.viewed = YES;
    
    [self updateStatusItemIcon];
    statusItemView.highlighted = NO;
    [popover close];
}

- (void)itemSelected:(NSMenuItem *)menuItem {
    
    FeedItem *item = [allItems objectAtIndex:menuItem.tag-1];
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
