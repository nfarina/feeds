#import "AppDelegate.h"
#import "PreferencesController.h"
#import "StatusItemView.h"
#import "Account.h"

#if DEBUG
const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
const int ddLogLevel = LOG_LEVEL_INFO;
#endif

#define MAX_ITEMS 30
#define MAX_GROWLS 3
#define POPOVER_INTERVAL 0.5
#define POPOVER_WIDTH 416

@interface AppDelegate () <NSApplicationDelegate, NSMenuDelegate, GrowlApplicationBridgeDelegate, NSUserNotificationCenterDelegate, NSAlertDelegate
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_10_11
// When we switched to build against the 10.11 SDK, the following interfaces
// are now protocols: (are interfaces in <=10.10)
, WebPolicyDelegate
#endif
>
@property (nonatomic, strong) IBOutlet NSMenu *menu;
@property (nonatomic, strong) IBOutlet NSMenuItem *markAllItemsAsReadItem;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) StatusItemView *statusItemView;
@property (nonatomic, strong) NSMutableArray *allItems;
@property (nonatomic, strong) NSTimer *refreshTimer, *checkUserNotificationsTimer;
@property (nonatomic, strong) Reachability *reachability;
@property (nonatomic, strong) PreferencesController *preferencesController;
@property (nonatomic, assign) BOOL menuNeedsRebuild;
@property (nonatomic, strong) NSMenuItem *lastHighlightedItem; // not retained
@property (nonatomic, strong) DDHotKeyCenter *hotKeyCenter;
@property (nonatomic, strong) DDFileLogger *fileLogger;
@property (nonatomic, strong) NSTimer *popoverTimer;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, strong) NSMenuItem *shimItem;
@property (nonatomic, assign) NSUInteger previouslyDeliveredNotifications;
@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    
    // initialize logging framework
    #if DEBUG
    // debug mode we'll log to Xcode and Console
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    #else
    // release mode we'll log to a file
    self.fileLogger = [[DDFileLogger alloc] init];
    self.fileLogger.maximumFileSize = 50 * 1024; // 50k per file max
    self.fileLogger.logFileManager.maximumNumberOfLogFiles = 1;
    [DDLog addLogger:self.fileLogger];
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

    self.hotKeyCenter = [DDHotKeyCenter new];
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	self.statusItem.menu = self.menu;

    self.statusItemView = [[StatusItemView alloc] initWithStatusItem:self.statusItem];
    self.statusItem.enabled = YES;

    self.popover = [[NSPopover alloc] init];
    [self.popover setContentViewController:[[NSViewController alloc] init]];
    [self.popover setBehavior:NSPopoverBehaviorTransient];
    [self.popover setAnimates:NO];
    
    WebView *webView = [[WebView alloc] initWithFrame:NSZeroRect];
    webView.drawsBackground = NO;
    webView.policyDelegate = self;
    webView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    [self.popover contentViewController].view = webView;

    self.shimItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
    self.shimItem.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)];

    self.allItems = [NSMutableArray new];
    
    self.reachability = [Reachability reachabilityForInternetConnection];
	[self.reachability startNotifier];

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
        self.checkUserNotificationsTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkUserNotifications) userInfo:nil repeats:YES];
        
        // did we open as the result of clicking a notification? (rare!)
        NSUserNotification *notification = (aNotification.userInfo)[NSApplicationLaunchUserNotificationKey];
        if (notification) [self userNotificationCenter:[NSUserNotificationCenter defaultUserNotificationCenter] didActivateNotification:notification];
    }
}

- (void)webRequestError:(NSError *)error {
    
    DDLogError(@"Web Request Error: %@", error);
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *urlAsString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL *url = [NSURL URLWithString:urlAsString];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GetURL" object:self userInfo:
     @{@"URL": url}];
}

- (void)setRefreshTimer:(NSTimer *)value {
    [_refreshTimer invalidate];
    _refreshTimer = value;
}

- (void)setPopoverTimer:(NSTimer *)value {
    [_popoverTimer invalidate];
    _popoverTimer = value;
}

- (void)hotKeysChanged {
    [self.hotKeyCenter unregisterHotKeysWithTarget:self];
    unsigned short code = [[NSUserDefaults standardUserDefaults] integerForKey:@"OpenMenuKeyCode"];
    NSUInteger flags = [[NSUserDefaults standardUserDefaults] integerForKey:@"OpenMenuKeyFlags"];
    if (code > 0)
        [self.hotKeyCenter registerHotKeyWithKeyCode:code modifierFlags:flags target:self action:@selector(openMenuHotkeyPressed) object:nil];
}

- (void)accountsChanged:(NSNotification *)notification {
    self.menuNeedsRebuild = YES;
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
    if (self.refreshTimer) {

        for (FeedItem *item in self.allItems)
            if (!item.viewed) {
                // you've got stuff up there that you haven't seen in the menu, so glow the icon to let you know!
                self.statusItemView.icon = StatusItemIconUnread;
                return;
            }

        // default
        self.statusItemView.icon = StatusItemIconNormal;
    }
    else // we're not running. 
        self.statusItemView.icon = StatusItemIconInactive;
}

- (void)reachabilityChanged {

    if ([self.reachability currentReachabilityStatus] != NotReachable) {
        
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
    
    NSError *error = [notification userInfo][NSUnderlyingErrorKey];
    SMWebRequest *request = [notification object];
    
    if ([[error domain] isEqual:(id)kCFErrorDomainCFNetwork]) {
        DDLogError(@"Network error while fetching feed: %@", request);
    }
    else {
        DDLogError(@"Failed with HTTP status code %i while fetching feed: %@", (int)[error code], request);
    }
}

- (void)feedUpdated:(NSNotification *)notification {
    self.menuNeedsRebuild = YES;

    Feed *feed = [notification object];
    
    // Show notifications if the user wants
    NotificationType notificationType = (NotificationType)[[NSUserDefaults standardUserDefaults] integerForKey:@"NotificationType"];
    
    if (HAS_NOTIFICATION_CENTER && notificationType == NotificationTypeUserNotificationCenter) {
        for (FeedItem *item in feed.items.reverseObjectEnumerator) {
            if (!item.notified) {
                NSUserNotification *notification = [[NSUserNotification alloc] init];
                
                notification.title = item.authorAndTitle.stringByDecodingCharacterEntities;
                notification.informativeText = [item.content.stringByFlatteningHTML stringByCondensingSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                notification.hasActionButton = NO;
                notification.userInfo = @{@"FeedItemLink": item.link.absoluteString};
                
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
    for (FeedItem *item in self.allItems)
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
    [self.allItems removeAllObjects];
  
    for (Account *account in [Account allAccounts])
        for (Feed *feed in account.enabledFeeds)
            for (FeedItem *item in feed.items)
                if (![self.allItems containsObject:item])
                    [self.allItems addObject:item];
    
    [self.allItems sortUsingSelector:@selector(compareItemByPublishedDate:)];

    //NSLog(@"ITEMS: %@", allItems);
    
    while ([self.allItems count] > MAX_ITEMS)
        [self.allItems removeObjectAtIndex:MAX_ITEMS];
    
    if (HAS_NOTIFICATION_CENTER) {
        NSMutableDictionary *itemsByLink = [NSMutableDictionary dictionary];
        
        // build a quick lookup dictionary for links
        for (FeedItem *item in self.allItems)
            itemsByLink[item.link.absoluteString] = item;
        
        // look through our delivered notifications and remove any that don't exist in our allItems anymore for whatever reason
        for (NSUserNotification *notification in [NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications) {
            NSString *link = (notification.userInfo)[@"FeedItemLink"];
            if (!itemsByLink[link])
                [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
        }
    }
}

- (void)rebuildMenuItems {
    
    while (![self.menu itemAtIndex:0].isSeparatorItem)
        [self.menu removeItemAtIndex:0];

    for (int i=0; i<self.allItems.count; i++) {
        
        FeedItem *item = self.allItems[i];
        
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(itemSelected:) keyEquivalent:@""];
        menuItem.attributedTitle = [item attributedStringHighlighted:NO];
        menuItem.image = item.feed.account.menuIconImage;
        menuItem.tag = i+1;
        
        if (!item.viewed) {
            menuItem.onStateImage = [NSImage imageNamed:@"Unread"];
            menuItem.state = NSOnState;
        }
        
        [self.menu insertItem:menuItem atIndex:i];
    }
    
    if (self.allItems.count) {
        // put the shim last
        [self.menu insertItem:self.shimItem atIndex:self.allItems.count];
    }
    else {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"No Items" action:NULL keyEquivalent:@""];
        [menuItem setEnabled:NO];
        [self.menu insertItem:menuItem atIndex:0];
    }
}

- (void)openMenuHotkeyPressed {
    [self.statusItemView toggleMenu];
}

- (void)menuWillOpen:(NSMenu *)menu {
    if (self.menuNeedsRebuild)
        [self rebuildMenuItems];
    
    [self.markAllItemsAsReadItem setEnabled:NO];
    for (FeedItem *item in self.allItems)
        if (!item.viewed)
            [self.markAllItemsAsReadItem setEnabled:YES];
}

- (void)highlightMenuItem:(NSMenuItem *)menuItem {
    
    if (self.lastHighlightedItem) {
        FeedItem *lastItem = self.allItems[self.lastHighlightedItem.tag-1];
        self.lastHighlightedItem.attributedTitle = [lastItem attributedStringHighlighted:NO];
    }

    if (menuItem) {
        FeedItem *item = self.allItems[menuItem.tag-1];
        menuItem.attributedTitle = [item attributedStringHighlighted:YES];
    }
    
    self.lastHighlightedItem = menuItem;
}

- (void)menu:(NSMenu *)theMenu willHighlightItem:(NSMenuItem *)menuItem {

    if (menuItem.tag > 0)
        [self highlightMenuItem:menuItem];
    else
        [self highlightMenuItem:nil];
    

    if (menuItem.tag > 0) {
        if ([self.popover isShown]) {
            [self showPopoverForMenuItem:menuItem]; // popover's already open, so switch to the new item immediately
        }
        else {
            // popover should open after you wait a tick
            NSRunLoop *runloop = [NSRunLoop currentRunLoop];
            self.popoverTimer = [NSTimer timerWithTimeInterval:POPOVER_INTERVAL target:self selector:@selector(showPopover:) userInfo:menuItem repeats:NO];
            [runloop addTimer:self.popoverTimer forMode:NSEventTrackingRunLoopMode];
            
            // clear popover contents in preparation for display
            WebView *webView = (WebView *)[self.popover contentViewController].view;
            [webView.mainFrame loadHTMLString:@"" baseURL:nil];
            [self.popover setContentSize:NSMakeSize(POPOVER_WIDTH, 100)];
        }
    }
    else {
        self.popoverTimer = nil;
        [self.popover close];
    }
}

- (void)showPopover:(NSTimer *)timer {
    [self showPopoverForMenuItem:timer.userInfo];
}

- (void)showPopoverForMenuItem:(NSMenuItem *)menuItem {

    FeedItem *item = self.allItems[menuItem.tag-1];

    menuItem.state = NSOffState;
    [self markItemAsViewed:item];

    WebView *webView = (WebView *)[self.popover contentViewController].view;
    
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
    
    if ([item.author length] > 0 && ([titleOrFallback containsString:item.author] || [item.content beginsWithString:item.author])) {
        // don't repeat the author in the subtitle if they are mentioned in the title or if the description
        // starts with the author name like "Nick Farina did something..."
        author = nil;
    }
    
    NSString *time = item.published.timeAgo;
    NSString *authorAndTime = author ? [NSString stringWithFormat:@"%@ - %@",author,time] : time;
    
    static NSString *css = nil;
    if (!css) {
        NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"Popover" ofType:@"css"];
        css = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:NULL];
    }
    
    // add an automatic CSS "class" of the selected item's account, for account-specific styling like "body.GithubAccount"
    NSString *bodyClass = NSStringFromClass(item.feed.account.class);
    
    // append "DarkMode" if we're in the new "Dark Mode" introduced with OS X 10.10 Yosemite
    id style = [[NSUserDefaults standardUserDefaults] persistentDomainForName:NSGlobalDomain][@"AppleInterfaceStyle"];
    BOOL darkMode = ( style && [style isKindOfClass:[NSString class]] && NSOrderedSame == [style caseInsensitiveCompare:@"dark"] );
    
    if (darkMode)
        bodyClass = [bodyClass stringByAppendingString:@" DarkMode"];
    
    NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"Popover" ofType:@"html"];
    NSString *template = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:NULL];
    NSString *rendered = [NSString stringWithFormat:template, css, bodyClass, [titleOrFallback truncatedAfterIndex:75], authorAndTime, item.content ?: @""];

    //NSLog(@"Rendered:\n%@\n", rendered);
    
    webView.alphaValue = 0;
    [webView.mainFrame loadHTMLString:rendered baseURL:item.feed.URL];

    NSMenuItem *shim = self.shimItem;
    NSRect frame = self.shimItem.view.superview.frame;
    
    NSInteger shimIndex = [self.menu indexOfItem:self.shimItem];
    NSInteger itemIndex = [self.menu indexOfItem:menuItem];
    
    int menuItemHeight = 20;
    
    // if on Yosemite or higher, system uses Helvetica which is slightly larger.
    if ([self.statusItem respondsToSelector:@selector(button)])
        menuItemHeight = 21;
    
    frame.origin.y += ((shimIndex-itemIndex)*menuItemHeight) - 10; // 10 to get to middle of the cell
    
    if (shim.view.superview.superview)
        [self.popover showRelativeToRect:frame ofView:shim.view.superview.superview preferredEdge:NSMinXEdge];
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener {	
	
    if (actionInformation[@"WebActionNavigationTypeKey"] != nil) {
        
        NSURL *URL = actionInformation[@"WebActionOriginalURLKey"];
        NSString *URLString = [URL absoluteString];
        
		if ([URLString rangeOfString:@"cmd://"].location != NSNotFound) {
            
            int height = [[URLString substringFromIndex:6] intValue];

            [self.popover setContentSize:NSMakeSize(POPOVER_WIDTH, height)];
            webView.alphaValue = 1;
            [webView stringByEvaluatingJavaScriptFromString:@"commandReceived()"];

            return;
        }
	}
    
	[listener use];
}

- (void)menuDidClose:(NSMenu *)menu {
    if (!self.popover)
        for (FeedItem *item in self.allItems)
            item.viewed = YES;
    
    [self updateStatusItemIcon];
    self.statusItemView.highlighted = NO;
    [self.popover close];
    [self highlightMenuItem:nil];
}

- (void)itemSelected:(NSMenuItem *)menuItem {
    
    FeedItem *item = self.allItems[menuItem.tag-1];
    
    menuItem.state = NSOffState;
    [self markItemAsViewed:item];
    
    [[NSWorkspace sharedWorkspace] openURL:item.link];
}

- (void)markItemAsViewed:(FeedItem *)item {
    item.viewed = YES;
    [self updateStatusItemIcon];
    self.menuNeedsRebuild = YES;

    if (HAS_NOTIFICATION_CENTER) {
        // if the item is in notification center, remove it
        for (NSUserNotification *notification in [NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications) {
            NSString *link = (notification.userInfo)[@"FeedItemLink"];
            if ([link isEqualToString:item.link.absoluteString])
                [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
        }
    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    NSString *link = (notification.userInfo)[@"FeedItemLink"];
    
    // if you activate the notification, that's the same as viewing an item.
    for (FeedItem *item in self.allItems)
        if ([item.link.absoluteString isEqual:link])
            [self markItemAsViewed:item];
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:link]];
}

- (void)checkUserNotifications {
    // this is all so you can click the little "X" in notification center and have the corresponding items
    // magically get "viewed" in feeds.
    
    NSUInteger deliveredNotifications = [NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications.count;
    
    if (self.previouslyDeliveredNotifications > 0 && deliveredNotifications == 0)
        [self markAllItemsAsRead:nil];
    
    self.previouslyDeliveredNotifications = deliveredNotifications;
}

- (void)growlNotificationWasClicked:(NSString *)URLString {
    if (URLString) {
        
        // if you click the growl notification, that's the same as viewing an item.
        for (FeedItem *item in self.allItems)
            if ([item.link.absoluteString isEqual:URLString])
                [self markItemAsViewed:item];

        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:URLString]];
    }
}

- (IBAction)openPreferences:(id)sender {

    if (!self.preferencesController)
        self.preferencesController = [[PreferencesController alloc] initPreferencesController];

	[self.preferencesController showPreferences];
}

-(IBAction)communitySupport:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://feedsapp.uservoice.com"]];
}

/**
 This is disabled since we don't really offer 1-on-1 support for Feeds now that it's free/open-source.
 Maybe replace this with a method that sends more anonymized data to the community support site.
 */
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
    NSString *appBuild = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    
    [errorReport appendFormat:@"Feeds Version: %@\nOS X Version: %@\n\n", appBuild, osxVersion];
    
    for (NSString *logFile in [self.fileLogger.logFileManager sortedLogFilePaths].reverseObjectEnumerator)
        [errorReport appendString:[NSString stringWithContentsOfFile:logFile encoding:NSUTF8StringEncoding error:NULL]];
    
    if (result == NSAlertDefaultReturn) { // Mail
        NSString *url = [NSString stringWithFormat:@"mailto:support@feedsapp.com?subject=Bug%%20Report&body=%@",
                         [errorReport stringByEscapingForURLArgument]];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
        
    }
    else if (result == NSAlertOtherReturn) { // Clipboard
        
        [[NSPasteboard generalPasteboard] declareTypes:@[NSStringPboardType] owner:nil];
        [[NSPasteboard generalPasteboard] setString:errorReport forType:NSStringPboardType];
        
        [[NSAlert alertWithMessageText:@"Copied to Clipboard" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"A detailed error report has been copied to your clipboard. Please paste it into the body of an email and send it to support@feedsapp.com."] runModalInForeground];
    }
}


@end
