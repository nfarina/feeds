#import "CreateAccountController.h"

#define DEFAULT_REFRESH_INTERVAL 30*60; // default to 30 minutes if none specified

typedef enum {
    NotificationTypeUserNotificationCenter = 0,
    NotificationTypeGrowl = 1,
    NotificationTypeDisabled = 2
} NotificationType;

@interface PreferencesController : NSWindowController

+ (void)migrateSettings; // from an older version of Feeds

- (id)initPreferencesController;
- (void)showPreferences;

@end
