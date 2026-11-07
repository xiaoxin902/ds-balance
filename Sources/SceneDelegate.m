// SPDX-License-Identifier: MIT
// Copyright (c) 2026 OwnGoal Studio
#import "SceneDelegate.h"
#import "DSAppearance.h"
#import "DSStore.h"
#import "DSTabBarController.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:UIWindowScene.class]) {
        return;
    }
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [DSTabBarController new];
    [DSAppearance apply];
    [self.window makeKeyAndVisible];
    [DSAppearance apply];

    [NSNotificationCenter.defaultCenter addObserver:self
                                          selector:@selector(handleAppearanceChange)
                                              name:DSAppearanceDidChangeNotification
                                            object:nil];
}

- (void)handleAppearanceChange {
    [DSAppearance apply];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end
