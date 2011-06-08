//
//  RSSMenuAppDelegate.h
//  RSSMenu
//
//  Created by Nick Farina on 6/8/11.
//  Copyright 2011 Spotlight Mobile. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RSSMenuAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
