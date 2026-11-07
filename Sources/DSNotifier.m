#import "DSNotifier.h"
#import "DSStore.h"

@implementation DSNotifier

+ (void)requestAuthorizationWithCompletion:(void (^)(BOOL))completion {
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError *error) {
        if (error) {
            NSLog(@"[DSBalance] notification authorization failed: %@", error);
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(granted);
            });
        }
    }];
}

+ (void)authorizationStatus:(void (^)(UNAuthorizationStatus))completion {
    [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(settings.authorizationStatus);
        });
    }];
}

+ (DSBalanceInfo *)primaryInfoFromInfos:(NSArray<DSBalanceInfo *> *)infos {
    DSBalanceInfo *first = nil;
    for (DSBalanceInfo *info in infos) {
        if (!first) {
            first = info;
        }
        if ([info.currency caseInsensitiveCompare:@"CNY"] == NSOrderedSame) {
            return info;
        }
    }
    return first;
}

+ (void)evaluateInfos:(NSArray<DSBalanceInfo *> *)infos {
    DSStore *store = DSStore.sharedStore;
    DSBalanceInfo *primary = [self primaryInfoFromInfos:infos];
    if (!primary) {
        return;
    }

    if (!store.notificationsEnabled || !store.lowBalanceAlertEnabled) {
        return;
    }

    double threshold = store.lowBalanceThreshold;
    if (primary.total > threshold) {
        if (store.lowBalanceNotified) {
            store.lowBalanceNotified = NO;
        }
        return;
    }

    if (store.lowBalanceNotified) {
        return;
    }
    store.lowBalanceNotified = YES;
    NSLog(@"[DSBalance] low balance alert: total=%.2f threshold=%.2f", primary.total, threshold);

    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = @"DeepSeek 余额偏低";
    content.body = [NSString stringWithFormat:@"当前余额 %@%@，已低于提醒线 %@%@。",
                                              primary.currencySymbol, DSMoneyText(primary.total),
                                              primary.currencySymbol, DSMoneyText(threshold)];
    content.sound = UNNotificationSound.defaultSound;

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"dsbalance-low"
                                                                          content:content
                                                                          trigger:nil];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request
                                                         withCompletionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"[DSBalance] low balance notification failed: %@", error);
        }
    }];
}

+ (void)sendTestNotificationWithInfos:(NSArray<DSBalanceInfo *> *)infos {
    DSBalanceInfo *primary = [self primaryInfoFromInfos:infos];
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = @"测试通知";
    content.body = primary
        ? [NSString stringWithFormat:@"余额 %@%@，通知通道正常。", primary.currencySymbol, DSMoneyText(primary.total)]
        : @"通知通道正常。";
    content.sound = UNNotificationSound.defaultSound;

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"dsbalance-test"
                                                                          content:content
                                                                          trigger:nil];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request
                                                         withCompletionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"[DSBalance] test notification failed: %@", error);
        }
    }];
}

@end
