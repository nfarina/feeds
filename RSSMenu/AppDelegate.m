#import "AppDelegate.h"
#import "Feed.h"
#import "HotKeys.h"
#import "StatusItemView.h"

#define MAX_ITEMS 30
#define MAX_GROWLS 3
#define CHECK_INTERVAL 60*1
#define POPOVER_INTERVAL 0.5
#define POPOVER_WIDTH 402

@interface AppDelegate ()
@property (nonatomic, retain) NSTimer *refreshTimer, *popoverTimer;
@property (nonatomic, retain) NSMenuItem *lastHighlightedItem;
- (NSArray *)allFeeds;
- (void)highlightMenuItem:(NSMenuItem *)menuItem;
- (void)showPopoverForMenuItem:(NSMenuItem *)menuItem;
- (void)accountsChanged:(NSNotification *)notification;
- (void)reachabilityChanged;
- (void)refreshFeeds;
- (void)openBrowserWithURL:(NSURL *)url;
- (void)updateStatusItemIcon;
@end

@implementation AppDelegate
@synthesize refreshTimer, popoverTimer, lastHighlightedItem;

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
    statusItem.enabled = YES;
    statusItem.view = statusItemView;

    if (NSClassFromString(@"NSPopover")) {
        popover = [[NSClassFromString(@"NSPopover") alloc] init];
        [popover setContentViewController:[[[NSViewController alloc] init] autorelease]];
        [popover setBehavior:NSPopoverBehaviorTransient];
        [popover setAnimates:NO];
        
        WebView *webView = [[[WebView alloc] initWithFrame:NSZeroRect] autorelease];
        webView.drawsBackground = NO;
        webView.policyDelegate = self;
        webView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
        [popover contentViewController].view = webView;
        
        shimItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
        shimItem.view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)] autorelease];
        [menu addItem:shimItem];
    }

    // register hot key for popping open the menu
    [HotKeys registerHotKeys];
    
    allItems = [NSMutableArray new];
    
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

- (void)setPopoverTimer:(NSTimer *)value {
    [popoverTimer invalidate];
    popoverTimer = [value retain];
}

- (NSArray *)allFeeds {
    NSMutableArray *feeds = [NSMutableArray array];
    for (Account *account in [Account allAccounts]) [feeds addObjectsFromArray:account.feeds];
    return feeds;
}

- (void)accountsChanged:(NSNotification *)notification {
    menuNeedsRebuild = YES;
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
    menuNeedsRebuild = YES;

    Feed *feed = [notification object];
    int notifications = 0;
    
    for (FeedItem *item in feed.items) {
        
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
    
    // rebuild allItems array
    [allItems removeAllObjects];
    
    for (Feed *feed in self.allFeeds)
        [allItems addObjectsFromArray:feed.items];
    
    [allItems sortUsingSelector:@selector(compareItemByPublishedDate:)];
    while ([allItems count] > MAX_ITEMS)
        [allItems removeObjectAtIndex:MAX_ITEMS];
    
    [self updateStatusItemIcon];
}

- (void)rebuildItems {
    
    while (![menu itemAtIndex:0].isSeparatorItem)
        [menu removeItemAtIndex:0];

    for (int i=0; i<allItems.count; i++) {
        
        FeedItem *item = [allItems objectAtIndex:i];
        
        NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:@selector(itemSelected:) keyEquivalent:@""] autorelease];
        menuItem.attributedTitle = [item attributedStringHighlighted:NO];
        menuItem.image = [NSImage imageNamed:[item.feed.account.type stringByAppendingString:@".png"]];
        menuItem.tag = i+1;
        
        if (!item.viewed) {
            menuItem.onStateImage = [NSImage imageNamed:@"Unread.png"];
            menuItem.state = NSOnState;
        }

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

- (void)menuWillOpen:(NSMenu *)menu {
    if (menuNeedsRebuild)
        [self rebuildItems];
}

- (void)highlightMenuItem:(NSMenuItem *)menuItem {
    
//    NSWindow *window = [NSApplication sharedApplication].keyWindow;
//    NSView *firstResponder = (NSView *)window.firstResponder;
//    NSLog(@"Window: %@ first responder %@ frame %@", window, firstResponder, NSStringFromRect(firstResponder.frame));
    
    if (lastHighlightedItem) {
        FeedItem *lastItem = [allItems objectAtIndex:lastHighlightedItem.tag-1];
        lastHighlightedItem.attributedTitle = [lastItem attributedStringHighlighted:NO];
//        lastHighlightedItem.image = [NSImage imageNamed:[lastItem.feed.account.type stringByAppendingString:@".png"]];
    }

    if (menuItem) {
        FeedItem *item = [allItems objectAtIndex:menuItem.tag-1];
        menuItem.attributedTitle = [item attributedStringHighlighted:YES];
        
//        NSImage *highlightedImage = [NSImage imageNamed:[item.feed.account.type stringByAppendingString:@"Highlighted.png"]];
//        if (highlightedImage) menuItem.image = highlightedImage;
    }
    
    self.lastHighlightedItem = menuItem;
}

- (void)menu:(NSMenu *)theMenu willHighlightItem:(NSMenuItem *)menuItem {

    if (menuItem.tag > 0)
        [self highlightMenuItem:menuItem];
    else
        [self highlightMenuItem:nil];
    
    if (popover) {

        if (menuItem.tag > 0) {
            if ([popover isShown]) {
                [self showPopoverForMenuItem:menuItem]; // popover's already open, so switch to the new item immediately
            }
            else {
                // popover should open after you wait a tick
                NSRunLoop *runloop = [NSRunLoop currentRunLoop];
                self.popoverTimer = [NSTimer timerWithTimeInterval:POPOVER_INTERVAL target:self selector:@selector(showPopover:) userInfo:menuItem repeats:NO];
                [runloop addTimer:popoverTimer forMode:NSEventTrackingRunLoopMode];
                
                // clear popover contents in preparation for display
                WebView *webView = (WebView *)[popover contentViewController].view;
                [webView.mainFrame loadHTMLString:@"" baseURL:nil];
                [popover setContentSize:NSMakeSize(POPOVER_WIDTH, 100)];
            }
        }
        else {
            self.popoverTimer = nil;
            [popover close];
        }
    }
}

- (void)showPopover:(NSTimer *)timer {
    [self showPopoverForMenuItem:timer.userInfo];
}

- (void)showPopoverForMenuItem:(NSMenuItem *)menuItem {

    FeedItem *item = [allItems objectAtIndex:menuItem.tag-1];

    menuItem.state = NSOffState;
    item.viewed = YES;

    WebView *webView = (WebView *)[popover contentViewController].view;
    
    NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"Popover" ofType:@"html"];
    NSString *template = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:NULL];
    NSString *rendered = [NSString stringWithFormat:template, [item.title truncatedAfterIndex:75], item.author, item.content];
    
    webView.alphaValue = 0;
    [webView.mainFrame loadHTMLString:rendered baseURL:nil];
    
    NSRect frame = shimItem.view.superview.frame;
    
    NSInteger shimIndex = [menu indexOfItem:shimItem];
    NSInteger itemIndex = [menu indexOfItem:menuItem];
    
    frame.origin.y += 6 + (19.333333 * (shimIndex-itemIndex-1));
    [popover showRelativeToRect:frame ofView:shimItem.view.superview.superview preferredEdge:NSMinXEdge];
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener {	
	
    if ([actionInformation objectForKey:@"WebActionNavigationTypeKey"] != nil) {
        
        NSURL *URL = [actionInformation objectForKey:@"WebActionOriginalURLKey"];
        NSString *URLString = [URL absoluteString];
        
		if ([URLString rangeOfString:@"cmd://"].location != NSNotFound) {
            
            int height = [[URLString substringFromIndex:6] intValue];

            [popover setContentSize:NSMakeSize(POPOVER_WIDTH, height)];
            webView.alphaValue = 1;
            [webView stringByEvaluatingJavaScriptFromString:@"commandReceived()"];

            return;
        }
	}
    
	[listener use];
}

- (void)menuDidClose:(NSMenu *)menu {
    if (!popover)
        for (FeedItem *item in allItems)
            item.viewed = YES;
    
    [self updateStatusItemIcon];
    statusItemView.highlighted = NO;
    [popover close];
    [self highlightMenuItem:nil];
}

- (void)itemSelected:(NSMenuItem *)menuItem {
    
    FeedItem *item = [allItems objectAtIndex:menuItem.tag-1];
    
    menuItem.state = NSOffState;
    item.viewed = YES;
    
    [self openBrowserWithURL:item.link];
}

- (void)growlNotificationWasClicked:(NSString *)URLString {
    if (URLString) {
        
        // if you click the growl notification, that's the same as viewing an item.
        for (FeedItem *item in allItems)
            if ([item.link.absoluteString isEqual:URLString]) {
                item.viewed = YES;
                [self updateStatusItemIcon];
                menuNeedsRebuild = YES;
            }
        
        [self openBrowserWithURL:[NSURL URLWithString:URLString]];
    }
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
