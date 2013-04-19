#import "AppDelegate.h"
#import "Feed.h"
#import "StatusItemView.h"

#if DEBUG
const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
const int ddLogLevel = LOG_LEVEL_INFO;
#endif

#define MAX_ITEMS 30
#define MAX_GROWLS 3
#define POPOVER_INTERVAL 0.5
#define POPOVER_WIDTH 416

@interface AppDelegate ()
@property (nonatomic, retain) NSTimer *refreshTimer, *popoverTimer;
@property (nonatomic, retain) NSMenuItem *lastHighlightedItem;
@end

@implementation AppDelegate
@synthesize refreshTimer, popoverTimer, lastHighlightedItem;

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    
    // initialize logging framework
    #if DEBUG
    // debug mode we'll log to Xcode and Console
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    #else
    // release mode we'll log to a file
    fileLogger = [[DDFileLogger alloc] init];
    fileLogger.maximumFileSize = 50 * 1024; // 50k per file max
    fileLogger.logFileManager.maximumNumberOfLogFiles = 1;
    [DDLog addLogger:fileLogger];
    #endif
    
    // listen for "Open URL" events sent to this app by the user clicking on a "feedsapp://something" link.
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    // show the dock icon immediately if necessary
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HideDockIcon"]) {
        ProcessSerialNumber psn = { 0, kCurrentProcess }; 
        TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    }

    // migrate any old preferences
    [PreferencesController migrateSettings];
        
    [GrowlApplicationBridge setGrowlDelegate:self];
    
    if (HAS_NOTIFICATION_CENTER)
        [NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;

    hotKeyCenter = [DDHotKeyCenter new];
    
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
	statusItem.menu = menu;

    statusItemView = [[StatusItemView alloc] initWithStatusItem:statusItem];
    statusItem.enabled = YES;
    statusItem.view = statusItemView;

    if (HAS_POPOVER) {
        popover = [[NSPopover alloc] init];
        [popover setContentViewController:[[[NSViewController alloc] init] autorelease]];
        [popover setBehavior:NSPopoverBehaviorTransient];
        [popover setAnimates:NO];
        
        WebView *webView = [[[WebView alloc] initWithFrame:NSZeroRect] autorelease];
        webView.drawsBackground = NO;
        webView.policyDelegate = self;
        webView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
        [popover contentViewController].view = webView;
    }

    allItems = [NSMutableArray new];
    
    reachability = [[Reachability reachabilityForInternetConnection] retain];
	[reachability startNotifier];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webRequestError:) name:kSMWebRequestError object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountsChanged:) name:kAccountsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kFeedUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedFailed:) name:kSMWebRequestError object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged) name:kReachabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hotKeysChanged) name:@"FeedsHotKeysChanged" object:nil];
        
    [self hotKeysChanged];
    [self reachabilityChanged];
    
#if DEBUG
    ProcessSerialNumber psn = { 0, kCurrentProcess }; 
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    [self openPreferences:nil];
#else
    // no accounts yet? help you add one
    if ([Account allAccounts].count <= 0)
        [self openPreferences:nil];
#endif

    [self accountsChanged:nil];
    
    if (HAS_NOTIFICATION_CENTER) {
        
        // setup our timer that checks periodically to see if you've dismissed any delivered NSUserNotifications so
        // we can update our menu
        checkUserNotificationsTimer = [[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkUserNotifications) userInfo:nil repeats:YES] retain];
        
        // did we open as the result of clicking a notification? (rare!)
        NSUserNotification *notification = [aNotification.userInfo objectForKey:NSApplicationLaunchUserNotificationKey];
        if (notification) [self userNotificationCenter:nil didActivateNotification:notification];
    }
}

- (void)webRequestError:(NSError *)error {
    
    DDLogError(@"Web Request Error: %@", error);
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *urlAsString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL *url = [NSURL URLWithString:urlAsString];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GetURL" object:self userInfo:
     [NSDictionary dictionaryWithObject:url forKey:@"URL"]];
}

- (void)setRefreshTimer:(NSTimer *)value {
    [refreshTimer invalidate];
    [refreshTimer release], refreshTimer = [value retain];
}

- (void)setPopoverTimer:(NSTimer *)value {
    [popoverTimer invalidate];
    [popoverTimer release], popoverTimer = [value retain];
}

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
        NSTimeInterval timeSinceRefresh = [NSDate timeIntervalSinceReferenceDate] - account.lastRefresh.timeIntervalSinceReferenceDate;
        if (timeSinceRefresh > account.refreshIntervalOrDefault)
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
        
        DDLogInfo(@"Internet is reachable. Refreshing and resetting timer.");
        
        [self refreshFeeds];
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refreshFeeds) userInfo:nil repeats:YES];
    }
    else {
        DDLogInfo(@"Internet is NOT reachable. Killing timer.");
        self.refreshTimer = nil;
    }
    
    [self updateStatusItemIcon];
}

- (void)feedFailed:(NSNotification *)notification {
    
    NSError *error = [[notification userInfo] objectForKey:NSUnderlyingErrorKey];
    SMWebRequest *request = [notification object];
    
    if ([[error domain] isEqual:(id)kCFErrorDomainCFNetwork]) {
        DDLogError(@"Network error while fetching feed: %@", request);
    }
    else {
        DDLogError(@"Failed with HTTP status code %i while fetching feed: %@", (int)[error code], request);
    }
}

- (void)feedUpdated:(NSNotification *)notification {
    menuNeedsRebuild = YES;

    Feed *feed = [notification object];
    
    // Show notifications if the user wants
    NotificationType notificationType = (NotificationType)[[NSUserDefaults standardUserDefaults] integerForKey:@"NotificationType"];
    
    if (HAS_NOTIFICATION_CENTER && notificationType == NotificationTypeUserNotificationCenter) {
        for (FeedItem *item in feed.items.reverseObjectEnumerator) {
            if (!item.notified) {
                NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
                
                notification.title = item.authorAndTitle.stringByDecodingCharacterEntities;
                notification.informativeText = [item.content.stringByFlatteningHTML stringByCondensingSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                notification.hasActionButton = NO;
                notification.userInfo = [NSDictionary dictionaryWithObject:item.link.absoluteString forKey:@"FeedItemLink"];
                
                [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
            }
        }
    }
    else if (notificationType == NotificationTypeGrowl) {
        int notifications = 0;
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
    }
    
    // mark all as notified
    for (FeedItem *item in feed.items)
        item.notified = YES;

    [self rebuildItems];
    [self updateStatusItemIcon];
}

- (void)markAllItemsAsRead:(id)sender {

    // mark all as viewed
    for (FeedItem *item in allItems)
        item.viewed = YES;

    if (HAS_NOTIFICATION_CENTER)
        [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    
    [self updateStatusItemIcon];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
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
    
    if (HAS_NOTIFICATION_CENTER) {
        NSMutableDictionary *itemsByLink = [NSMutableDictionary dictionary];
        
        // build a quick lookup dictionary for links
        for (FeedItem *item in allItems)
            [itemsByLink setObject:item forKey:item.link.absoluteString];
        
        // look through our delivered notifications and remove any that don't exist in our allItems anymore for whatever reason
        for (NSUserNotification *notification in [NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications) {
            NSString *link = [notification.userInfo objectForKey:@"FeedItemLink"];
            if (![itemsByLink objectForKey:link])
                [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
        }
    }
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
            menuItem.onStateImage = [NSImage imageNamed:@"Unread.tiff"];
            menuItem.state = NSOnState;
        }
        
        [menu insertItem:menuItem atIndex:i];
    }
    
    if (allItems.count) {
        // put the shim last
        [menu insertItem:shimItem atIndex:allItems.count];
    }
    else {
        NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"No Items" action:NULL keyEquivalent:@""] autorelease];
        [menuItem setEnabled:NO];
        [menu insertItem:menuItem atIndex:0];
    }
}

- (void)openMenuHotkeyPressed {
    [statusItemView toggleMenu];
}

- (void)menuWillOpen:(NSMenu *)menu {
    if (menuNeedsRebuild)
        [self rebuildMenuItems];
    
    [markAllItemsAsReadItem setEnabled:NO];
    for (FeedItem *item in allItems)
        if (!item.viewed)
            [markAllItemsAsReadItem setEnabled:YES];
}

- (void)highlightMenuItem:(NSMenuItem *)menuItem {
    
    if (lastHighlightedItem) {
        FeedItem *lastItem = [allItems objectAtIndex:lastHighlightedItem.tag-1];
        lastHighlightedItem.attributedTitle = [lastItem attributedStringHighlighted:NO];
    }

    if (menuItem) {
        FeedItem *item = [allItems objectAtIndex:menuItem.tag-1];
        menuItem.attributedTitle = [item attributedStringHighlighted:YES];
    }
    
    self.lastHighlightedItem = menuItem;
}

- (void)menu:(NSMenu *)theMenu willHighlightItem:(NSMenuItem *)menuItem {

    if (menuItem.tag > 0)
        [self highlightMenuItem:menuItem];
    else
        [self highlightMenuItem:nil];
    
    if (HAS_POPOVER) {

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
    [self markItemAsViewed:item];

    WebView *webView = (WebView *)[popover contentViewController].view;
    
    NSString *titleOrFallback = item.title;
    
    if (!titleOrFallback.length) {
        if (item.project)
            titleOrFallback = item.project;
        else if (item.feed.account.name.length)
            titleOrFallback = [NSString stringWithFormat:@"%@ (%@)", item.feed.title, item.feed.account.name];
        else if (item.feed.account.domain.length)
            titleOrFallback = [NSString stringWithFormat:@"%@ (%@)", item.feed.title, item.feed.account.domain];
        else
            titleOrFallback = item.feed.title;
    }
    else {
        // if you've picked a custom name, put it in parens after
        if (item.feed.account.name.length)
            titleOrFallback = [NSString stringWithFormat:@"%@ (%@)", item.title, item.feed.account.name];
    }
    
    NSString *author = item.author;
    
    if ([titleOrFallback containsString:item.author] || [item.content beginsWithString:item.author]) {
        // don't repeat the author in the subtitle if they are mentioned in the title or if the description
        // starts with the author name like "Nick Farina did something..."
        author = nil;
    }
    
    NSString *time = item.published.timeAgo;
    NSString *authorAndTime = author ? [NSString stringWithFormat:@"%@ - %@",author,time] : time;
    
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

    NSMenuItem *shim = shimItem;
    NSRect frame = shimItem.view.superview.frame;
    
    NSInteger shimIndex = [menu indexOfItem:shimItem];
    NSInteger itemIndex = [menu indexOfItem:menuItem];
    
    frame.origin.y += ((shimIndex-itemIndex)*20) - 10; // 10 to get to middle of the cell
    
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
    [self markItemAsViewed:item];
    
    [[NSWorkspace sharedWorkspace] openURL:item.link];
}

- (void)markItemAsViewed:(FeedItem *)item {
    item.viewed = YES;
    [self updateStatusItemIcon];
    menuNeedsRebuild = YES;

    if (HAS_NOTIFICATION_CENTER) {
        // if the item is in notification center, remove it
        for (NSUserNotification *notification in [NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications) {
            NSString *link = [notification.userInfo objectForKey:@"FeedItemLink"];
            if ([link isEqualToString:item.link.absoluteString])
                [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
        }
    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    NSString *link = [notification.userInfo objectForKey:@"FeedItemLink"];
    
    // if you activate the notification, that's the same as viewing an item.
    for (FeedItem *item in allItems)
        if ([item.link.absoluteString isEqual:link])
            [self markItemAsViewed:item];
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:link]];
}

- (void)checkUserNotifications {
    // this is all so you can click the little "X" in notification center and have the corresponding items
    // magically get "viewed" in feeds.

    if ([NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications.count == 0)
        [self markAllItemsAsRead:nil];
}

- (void)growlNotificationWasClicked:(NSString *)URLString {
    if (URLString) {
        
        // if you click the growl notification, that's the same as viewing an item.
        for (FeedItem *item in allItems)
            if ([item.link.absoluteString isEqual:URLString])
                [self markItemAsViewed:item];

        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:URLString]];
    }
}

- (IBAction)openPreferences:(id)sender {

    if (!preferencesController)
        preferencesController = [[PreferencesController alloc] initPreferencesController];

	[preferencesController showPreferences];
}

- (void)reportBug:(id)sender {
    NSInteger result = [[NSAlert alertWithMessageText:@"Bug Report" defaultButton:@"Compose Email" alternateButton:@"Cancel" otherButton:@"Copy to Clipboard" informativeTextWithFormat:@"Sorry you're having trouble! Just click \"Compose Email\" to email us from your default mail client. Alternatively, you can copy the information we need to your clipboard and paste it in your preferred email client."] runModalInForeground];
    
    if (result == NSAlertAlternateReturn)
        return; // don't do any work
    
    [DDLog flushLog];
    
    NSString *errorReportPath = [[NSBundle mainBundle] pathForResource:@"ErrorReport" ofType:@"txt"];
    NSMutableString *errorReport = [NSMutableString stringWithContentsOfFile:errorReportPath encoding:NSUTF8StringEncoding error:NULL];
    
    // write basic data
    SInt32 major, minor, bugfix;
    Gestalt(gestaltSystemVersionMajor, &major);
    Gestalt(gestaltSystemVersionMinor, &minor);
    Gestalt(gestaltSystemVersionBugFix, &bugfix);
    
    NSString *osxVersion = [NSString stringWithFormat:@"%d.%d.%d",(int)major,(int)minor,(int)bugfix];
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuild = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    
    [errorReport appendFormat:@"Feeds Version: %@ [Build %@]\nOS X Version: %@\n\n", appVersion, appBuild, osxVersion];
    
    for (NSString *logFile in [fileLogger.logFileManager sortedLogFilePaths].reverseObjectEnumerator)
        [errorReport appendString:[NSString stringWithContentsOfFile:logFile encoding:NSUTF8StringEncoding error:NULL]];
    
    if (result == NSAlertDefaultReturn) { // Mail
        NSString *url = [NSString stringWithFormat:@"mailto:support@feedsapp.com?subject=Bug%%20Report&body=%@",
                         [errorReport stringByEscapingForURLArgument]];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
        
    }
    else if (result == NSAlertOtherReturn) { // Clipboard
        
        [[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
        [[NSPasteboard generalPasteboard] setString:errorReport forType:NSStringPboardType];
        
        [[NSAlert alertWithMessageText:@"Copied to Clipboard" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"A detailed error report has been copied to your clipboard. Please paste it into the body of an email and send it to support@feedsapp.com."] runModalInForeground];
    }
}


@end
