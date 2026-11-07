#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A small filled line chart, drawn with Core Graphics: no third-party code.
@interface DSLineChartView : UIView

/// Oldest first.
@property (nonatomic, copy) NSArray<NSNumber *> *values;
@property (nonatomic, strong) UIColor *lineColor;

@end

NS_ASSUME_NONNULL_END
