#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A filled line chart with axis labels, drawn with Core Graphics.
@interface DSLineChartView : UIView

/// Oldest first. values and timestamps must line up.
@property (nonatomic, copy) NSArray<NSNumber *> *values;
@property (nonatomic, copy) NSArray<NSNumber *> *timestamps;
@property (nonatomic, copy) NSString *currencySymbol;
@property (nonatomic, strong) UIColor *lineColor;

@end

NS_ASSUME_NONNULL_END
