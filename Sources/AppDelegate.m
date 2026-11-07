// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OwnGoal Studio
#import "AppDelegate.h"
#import "DSBalanceInfo.h"
#import "DSApiClient.h"
#import "DSNotifier.h"
#import "DSStore.h"
#import <BackgroundTasks/BackgroundTasks.h>
#import <UserNotifications/UserNotifications.h>

static NSString *const kRefreshTaskIdentifier = @"bc.8848.dsbalance.refresh";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self registerBackgroundRefresh];
    UNUserNotificationCenter.currentNotificationCenter.delegate = self;

    DSStore *store = DSStore.sharedStore; // First access registers the defaults.
    (void)store;
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self scheduleBackgroundRefresh];
}

#pragma mark - UNUserNotificationCenterDelegate

/// Without this the system swallows an alert while the app is in front, which
/// looked exactly like "the test notification never arrived".
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner |
                      UNNotificationPresentationOptionList |
                      UNNotificationPresentationOptionSound);
}

#pragma mark - Background refresh

- (void)registerBackgroundRefresh {
    if (@available(iOS 13.0, *)) {
        __weak AppDelegate *weakSelf = self;
        [BGTaskScheduler.sharedScheduler registerForTaskWithIdentifier:kRefreshTaskIdentifier
                                                            usingQueue:nil
                                                         launchHandler:^(BGTask *task) {
            [weakSelf handleRefreshTask:task];
        }];
    }
}

- (void)scheduleBackgroundRefresh {
    if (@available(iOS 13.0, *)) {
        BGAppRefreshTaskRequest *request = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:kRefreshTaskIdentifier];
        request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:20 * 60];
        NSError *error = nil;
        [BGTaskScheduler.sharedScheduler submitTaskRequest:request error:&error];
        if (error) {
            NSLog(@"[DSBalance] could not schedule background refresh: %@", error);
        }
    }
}

- (void)handleRefreshTask:(BGTask *)task {
    if (@available(iOS 13.0, *)) {
        BGAppRefreshTask *refreshTask = [task isKindOfClass:BGAppRefreshTask.class] ? (BGAppRefreshTask *)task : nil;
        [self scheduleBackgroundRefresh];

        NSString *key = DSStore.sharedStore.apiKey;
        if (key.length == 0) {
            [task setTaskCompletedWithSuccess:NO];
            return;
        }

        __block BOOL finished = NO;
        task.expirationHandler = ^{
            finished = YES;
        };

        [DSApiClient fetchBalanceWithKey:key completion:^(BOOL available, NSArray<DSBalanceInfo *> *infos, NSError *error) {
            (void)available;
            if (finished) {
                return;
            }
            finished = YES;
            if (!error) {
                DSBalanceInfo *primary = [DSNotifier primaryInfoFromInfos:infos];
                [DSStore.sharedStore addSnapshotWithInfo:primary];
                [DSNotifier evaluateInfos:infos];
            }
            [refreshTask setTaskCompletedWithSuccess:(error == nil)];
        }];
    }
}

@end
