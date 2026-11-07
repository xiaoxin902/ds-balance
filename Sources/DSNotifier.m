#import "DSNotifier.h"
#import "DSStore.h"

static BOOL DSNotificationsAuthorized = NO;

@implementation DSNotifier

+ (BOOL)isUserAppInstallation {
    NSString *path = NSBundle.mainBundle.bundlePath;
    // A jailbreak install lives under …/Bundle/Application/.procursus/Applications
    // (a rootless bootstrap), so the container prefix alone says nothing.
    if ([path containsString:@".procursus"] || [path containsString:@"/Applications/"]) {
        return NO;
    }
    return [path containsString:@"/containers/Bundle/Application/"];
}

+ (void)prepareNotifications {
    if (![self isUserAppInstallation]) {
        // A platform app under /Applications is refused by the system, so
        // asking would only produce a silent NO.
        return;
    }
    [self requestAuthorizationWithCompletion:^(BOOL granted) {
        DSNotificationsAuthorized = granted;
    }];
}

+ (void)refreshAuthorizationStatus {
    [self authorizationStatus:^(UNAuthorizationStatus status) {
        DSNotificationsAuthorized = (status == UNAuthorizationStatusAuthorized ||
                                     status == UNAuthorizationStatusProvisional ||
                                     status == UNAuthorizationStatusEphemeral);
    }];
}

+ (BOOL)systemNotificationsAvailable {
    return DSNotificationsAuthorized;
}

+ (void)requestAuthorizationWithCompletion:(void (^)(BOOL))completion {
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError *error) {
        if (error) {
            NSLog(@"[DSBalance] notification authorization failed: %@", error);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            DSNotificationsAuthorized = granted;
            if (completion) {
                completion(granted);
            }
        });
    }];
}

+ (void)authorizationStatus:(void (^)(UNAuthorizationStatus))completion {
    [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            DSNotificationsAuthorized = (settings.authorizationStatus == UNAuthorizationStatusAuthorized ||
                                         settings.authorizationStatus == UNAuthorizationStatusProvisional ||
                                         settings.authorizationStatus == UNAuthorizationStatusEphemeral);
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

+ (BOOL)shouldWarnForInfo:(DSBalanceInfo *)info {
    DSStore *store = DSStore.sharedStore;
    if (!info || !store.lowBalanceAlertEnabled) {
        return NO;
    }
    if (info.total > store.lowBalanceThreshold) {
        store.lowBalanceNotified = NO;
        return NO;
    }
    if (store.lowBalanceNotified) {
        return NO;
    }
    store.lowBalanceNotified = YES;
    return YES;
}

+ (void)deliverLowBalanceAlertForInfo:(DSBalanceInfo *)info {
    if (![self systemNotificationsAvailable]) {
        return;
    }
    DSStore *store = DSStore.sharedStore;
    if (!store.notificationsEnabled) {
        return;
    }
    NSString *body = [NSString stringWithFormat:@"当前余额 %@%@，已低于提醒线 %@%@。",
                      info.currencySymbol, DSMoneyText(info.total),
                      info.currencySymbol, DSMoneyText(store.lowBalanceThreshold)];
    [self postNotificationWithTitle:@"DeepSeek 余额偏低" body:body identifier:@"dsbalance-low"];
}

+ (void)postTestNotification {
    [self postNotificationWithTitle:@"测试通知"
                               body:@"通知通道正常，余额偏低时会这样提醒你。"
                         identifier:@"dsbalance-test"];
}

+ (void)postNotificationWithTitle:(NSString *)title body:(NSString *)body identifier:(NSString *)identifier {
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title;
    content.body = body;
    content.sound = UNNotificationSound.defaultSound;

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                         content:content
                                                                         trigger:nil];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request
                                                         withCompletionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"[DSBalance] notification failed: %@", error);
        }
    }];
}

@end
