#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "DSBalanceInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSNotifier : NSObject

/// YES when the app runs from the user-app container (an IPA installed by
/// TrollStore, AltStore, Sideloadly). Only then does iOS grant notifications;
/// an app under /Applications is a platform component and is refused.
+ (BOOL)isUserAppInstallation;

/// Asks for permission on a side-loaded install; does nothing otherwise.
+ (void)prepareNotifications;
/// Re-reads the system setting, e.g. after returning to the foreground.
+ (void)refreshAuthorizationStatus;
+ (BOOL)systemNotificationsAvailable;

+ (void)requestAuthorizationWithCompletion:(nullable void (^)(BOOL granted))completion;
+ (void)authorizationStatus:(void (^)(UNAuthorizationStatus status))completion;

/// YES once, when the newest balance crosses the threshold; resets when it rises.
+ (BOOL)shouldWarnForInfo:(DSBalanceInfo *)info;
/// Sends the low-balance alert through the system when it is available.
+ (void)deliverLowBalanceAlertForInfo:(DSBalanceInfo *)info;
+ (void)postTestNotification;

+ (nullable DSBalanceInfo *)primaryInfoFromInfos:(NSArray<DSBalanceInfo *> *)infos;

@end

NS_ASSUME_NONNULL_END
