#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Applies the saved appearance to every window of the app.
@interface DSAppearance : NSObject

+ (void)apply;

+ (UIColor *)brandColor;
+ (UIColor *)warningBackgroundColor;
+ (UIColor *)warningTextColor;
+ (UIColor *)cardColor;

@end

NS_ASSUME_NONNULL_END
