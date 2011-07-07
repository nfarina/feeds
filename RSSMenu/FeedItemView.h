#import "Feed.h"

@interface FeedItemView : NSView {
    NSMenuItem *menuItem; // not retained
    FeedItem *item;
}

@property (nonatomic, assign) NSMenuItem *menuItem;
@property (nonatomic, retain) FeedItem *item;

@end
