#import "DSAppearance.h"
#import "DSStore.h"

@implementation DSAppearance

+ (UIUserInterfaceStyle)styleForMode:(DSAppearanceMode)mode {
    switch (mode) {
        case DSAppearanceModeLight:
            return UIUserInterfaceStyleLight;
        case DSAppearanceModeDark:
            return UIUserInterfaceStyleDark;
        case DSAppearanceModeSystem:
        default:
            return UIUserInterfaceStyleUnspecified;
    }
}

+ (void)apply {
    UIUserInterfaceStyle style = [self styleForMode:DSStore.sharedStore.appearanceMode];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.overrideUserInterfaceStyle != style) {
                window.overrideUserInterfaceStyle = style;
            }
        }
    }
}

+ (UIColor *)brandColor {
    // DeepSeek's blue, with a slightly lifted variant for dark mode.
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.42 green:0.53 blue:1.00 alpha:1.0]
            : [UIColor colorWithRed:0.30 green:0.42 blue:1.00 alpha:1.0];
    }];
}

+ (UIColor *)warningBackgroundColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.38 green:0.26 blue:0.02 alpha:1.0]
            : [UIColor colorWithRed:1.00 green:0.95 blue:0.82 alpha:1.0];
    }];
}

+ (UIColor *)warningTextColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:1.00 green:0.80 blue:0.42 alpha:1.0]
            : [UIColor colorWithRed:0.55 green:0.36 blue:0.00 alpha:1.0];
    }];
}

+ (UIColor *)cardColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0]
            : [UIColor colorWithRed:0.96 green:0.96 blue:0.97 alpha:1.0];
    }];
}

@end
