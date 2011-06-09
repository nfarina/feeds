#import "AppDelegate.h"

@interface AppDelegate ()
@property (nonatomic, retain) NSStatusItem *statusItem;
@end

@implementation AppDelegate
@synthesize menu, statusItem;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	statusItem.menu = menu;
    
    [statusItem setHighlightMode:YES];
	[statusItem setImage:[NSImage imageNamed:@"StatusItem.png"]];
	[statusItem setAlternateImage:[NSImage imageNamed:@"StatusItemSelected.png"]];
	[statusItem setEnabled:YES];
}

@end
