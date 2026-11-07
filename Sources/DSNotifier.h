#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "DSBalanceInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSNotifier : NSObject

/// Asks the system once; safe to call on every launch.
+ (void)requestAuthorizationWithCompletion:(nullable void (^)(BOOL granted))completion;
+ (void)authorizationStatus:(void (^)(UNAuthorizationStatus status))completion;

/// Sends the low-balance alert when the newest balance crosses the threshold.
+ (void)evaluateInfos:(NSArray<DSBalanceInfo *> *)infos;
/// A local notification right now, for the test row in Settings.
+ (void)sendTestNotificationWithInfos:(nullable NSArray<DSBalanceInfo *> *)infos;

+ (nullable DSBalanceInfo *)primaryInfoFromInfos:(NSArray<DSBalanceInfo *> *)infos;

@end

NS_ASSUME_NONNULL_END
