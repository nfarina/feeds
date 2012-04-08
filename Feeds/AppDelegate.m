#import "AppDelegate.h"
#import "Feed.h"
#import "StatusItemView.h"

// TODO: Growl popup shows author too?

#ifdef DEBUG
#define PER_ITEM_SHIM_STRATEGY 1
#define MAX_ITEMS 9999
#else
#define PER_ITEM_SHIM_STRATEGY 0
#define MAX_ITEMS 30
#endif
#define MAX_GROWLS 3
#define POPOVER_INTERVAL 0.5
#define POPOVER_WIDTH 416

@interface AppDelegate ()
@property (nonatomic, retain) NSTimer *refreshTimer, *popoverTimer;
@property (nonatomic, retain) NSMenuItem *lastHighlightedItem;
- (void)highlightMenuItem:(NSMenuItem *)menuItem;
- (void)showPopoverForMenuItem:(NSMenuItem *)menuItem;
- (void)accountsChanged:(NSNotification *)notification;
- (void)hotKeysChanged;
- (void)reachabilityChanged;
- (void)refreshFeeds;
- (void)rebuildItems;
- (void)openBrowserWithURL:(NSURL *)url;
- (void)updateStatusItemIcon;
@end

@implementation AppDelegate
@synthesize refreshTimer, popoverTimer, lastHighlightedItem;

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    // listen for "Open URL" events sent to this app by the user clicking on a "feedsapp://something" link.
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    #ifdef EXPIRATION_DATE
    NSTimeInterval timeLeft = AutoFormatDate([EXPIRATION_DATE stringByAppendingString:@"T11:00:50-05:00"]).timeIntervalSinceReferenceDate - [NSDate timeIntervalSinceReferenceDate];
    if (timeLeft > 0) {
        [[NSAlert alertWithMessageText:@"Test Version" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"This test version of Feeds will expire in %i days. Additionally, changes to your accounts will not be saved (for data integrity purposes).",(int)(timeLeft/60/60/24)] runModalInForeground];
    }
    else {
        NSLog(@"Trial over.");
        [[NSAlert alertWithMessageText:@"Test Expired" defaultButton:@"Quit" alternateButton:nil otherButton:nil informativeTextWithFormat:@"This test version of Feeds has expired."] runModalInForeground];
        exit(0);
    }
    #endif
    
    // show the dock icon immediately if necessary
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HideDockIcon"]) {
        ProcessSerialNumber psn = { 0, kCurrentProcess }; 
        TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    }

    [GrowlApplicationBridge setGrowlDelegate:self];

    hotKeyCenter = [DDHotKeyCenter new];
    
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

        #if !PER_ITEM_SHIM_STRATEGY
        shimItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
        shimItem.view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)] autorelease];
        [menu addItem:shimItem];
        #endif
    }

    allItems = [NSMutableArray new];
    
    reachability = [[Reachability reachabilityForInternetConnection] retain];
	[reachability startNotifier];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountsChanged:) name:kAccountsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kFeedUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedFailed:) name:kSMWebRequestError object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged) name:kReachabilityChangedNotification object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshIntervalChanged) name:@"RefreshIntervalChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hotKeysChanged) name:@"FeedsHotKeysChanged" object:nil];
    
    [self hotKeysChanged];
    [self reachabilityChanged];
    
#if DEBUG
    ProcessSerialNumber psn = { 0, kCurrentProcess }; 
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    [self openPreferences:nil];
#endif

    [self accountsChanged:nil];
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *urlAsString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL *url = [NSURL URLWithString:urlAsString];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GetURL" object:self userInfo:
     [NSDictionary dictionaryWithObject:url forKey:@"URL"]];
}

//- (NSTimeInterval)refreshInterval {
//    return [[NSUserDefaults standardUserDefaults] integerForKey:@"RefreshInterval"] ?: DEFAULT_REFRESH_INTERVAL;
//}

- (void)setRefreshTimer:(NSTimer *)value {
    [refreshTimer invalidate];
    [refreshTimer release], refreshTimer = [value retain];
}

- (void)setPopoverTimer:(NSTimer *)value {
    [popoverTimer invalidate];
    [popoverTimer release], popoverTimer = [value retain];
}

//- (void)refreshIntervalChanged {
//    [self reachabilityChanged]; // trigger a timer reset
//}

- (void)hotKeysChanged {
    [hotKeyCenter unregisterHotKeysWithTarget:self];
    unsigned short code = [[NSUserDefaults standardUserDefaults] integerForKey:@"OpenMenuKeyCode"];
    NSUInteger flags = [[NSUserDefaults standardUserDefaults] integerForKey:@"OpenMenuKeyFlags"];
    if (code > 0)
        [hotKeyCenter registerHotKeyWithKeyCode:code modifierFlags:flags target:self action:@selector(openMenuHotkeyPressed) object:nil];
}

- (void)accountsChanged:(NSNotification *)notification {
    menuNeedsRebuild = YES;
    [self rebuildItems]; // this will remove any items in feeds that may have just been removed
    [self refreshFeeds];
}

- (void)refreshFeeds {
    for (Account *account in [Account allAccounts]) {
        
        #ifdef ISOLATE_ACCOUNTS
        if (![ISOLATE_ACCOUNTS containsObject:NSStringFromClass(account.class)]) continue;
        #endif
        
        // only refresh if needed
        if (([NSDate timeIntervalSinceReferenceDate] - account.lastRefresh.timeIntervalSinceReferenceDate) > account.refreshInterval)
            [account refreshEnabledFeeds];
    }
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
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refreshFeeds) userInfo:nil repeats:YES];
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
    
    // Show Growl notifications if the user wants
    BOOL disableNotifications = [[NSUserDefaults standardUserDefaults] boolForKey:@"DisableNotifications"];
    
    if (!disableNotifications)
        for (FeedItem *item in feed.items) {
            if (!item.notified && notifications++ < MAX_GROWLS) {
                [GrowlApplicationBridge
                 notifyWithTitle:[item.authorAndTitle.stringByDecodingCharacterEntities truncatedAfterIndex:45]
                 description:[[item.content.stringByFlatteningHTML stringByCondensingSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] truncatedAfterIndex:90]
                 notificationName:@"NewItem"
                 iconData:feed.account.notifyIconData
                 priority:(signed int)0
                 isSticky:FALSE
                 clickContext:[item.link absoluteString]];
            }
        }
    
    // mark all as notified
    for (FeedItem *item in feed.items)
        item.notified = YES;

    [self rebuildItems];
    [self updateStatusItemIcon];
}

- (void)rebuildItems {
    // rebuild allItems array
    [allItems removeAllObjects];
    
    for (Account *account in [Account allAccounts])
        for (Feed *feed in account.enabledFeeds)
            [allItems addObjectsFromArray:feed.items];
    
    [allItems sortUsingSelector:@selector(compareItemByPublishedDate:)];
    
    //NSLog(@"ITEMS: %@", allItems);
    
    while ([allItems count] > MAX_ITEMS)
        [allItems removeObjectAtIndex:MAX_ITEMS];
}

- (void)rebuildMenuItems {
    
    while (![menu itemAtIndex:0].isSeparatorItem)
        [menu removeItemAtIndex:0];

    for (int i=0; i<allItems.count; i++) {
        
        FeedItem *item = [allItems objectAtIndex:i];
        
        NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:@selector(itemSelected:) keyEquivalent:@""] autorelease];
        menuItem.attributedTitle = [item attributedStringHighlighted:NO];
        menuItem.image = item.feed.account.menuIconImage;
        menuItem.tag = i+1;
        
        if (!item.viewed) {
            menuItem.onStateImage = [NSImage imageNamed:@"Unread.png"];
            menuItem.state = NSOnState;
        }
        
        #if PER_ITEM_SHIM_STRATEGY
        [menu insertItem:menuItem atIndex:i*2];
        NSMenuItem *shim = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
        shim.view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)] autorelease];
        [menu insertItem:shim atIndex:i*2]; // above
        #else
        [menu insertItem:menuItem atIndex:i];
        #endif
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
        [self rebuildMenuItems];
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
    
    NSString *titleOrFallback = item.title;
    
    if (!titleOrFallback.length) {
        if (item.project)
            titleOrFallback = item.project;
        else if (item.feed.account.domain)
            titleOrFallback = [NSString stringWithFormat:@"%@ (%@)", item.feed.title, item.feed.account.domain];
        else
            titleOrFallback = item.feed.title;
    }
    
    NSString *author = item.author;
    
    /*if ([titleOrFallback beginsWithString:item.author]) {
        // remove the author from the front of the title if the title begins with the author name
        titleOrFallback = [titleOrFallback substringFromIndex:item.author.length];
    }
    else*/ if ([titleOrFallback containsString:item.author]) {
        // don't repeat the author in the subtitle if they are mentioned in the title
        author = nil;
    }
    
    NSString *time = item.published.timeAgo;
    NSString *authorAndTime = author ? [NSString stringWithFormat:@"%@ - %@",author,time] : time;
    
//    #if USER_DEBUG
//    authorAndTime = [authorAndTime stringByAppendingFormat:@" (%@)", item.rawDate];
//    #endif

    static NSString *css = nil;
    if (!css) {
        NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"Popover" ofType:@"css"];
        css = [[NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:NULL] retain];
    }
    
    NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"Popover" ofType:@"html"];
    NSString *template = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:NULL];
    NSString *rendered = [NSString stringWithFormat:template, css, [titleOrFallback truncatedAfterIndex:75], authorAndTime, item.content ?: @""];

    webView.alphaValue = 0;
    [webView.mainFrame loadHTMLString:rendered baseURL:nil];

    #if PER_ITEM_SHIM_STRATEGY
    NSMenuItem *shim = [menu itemAtIndex:[menu indexOfItem:menuItem]-1];
    NSRect frame = shim.view.superview.frame;
    frame.origin.y -= 10; // the shim sits on the top of the menu item it represents - this will nudge it down to vertically center over the item.
    #else
    NSMenuItem *shim = shimItem;
    NSRect frame = shimItem.view.superview.frame;
    
    NSInteger shimIndex = [menu indexOfItem:shimItem];
    NSInteger itemIndex = [menu indexOfItem:menuItem];
    
    frame.origin.y += 12 + (19.333333 * (shimIndex-itemIndex-1));
    #endif
    
    if (shim.view.superview.superview)
        [popover showRelativeToRect:frame ofView:shim.view.superview.superview preferredEdge:NSMinXEdge];
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
