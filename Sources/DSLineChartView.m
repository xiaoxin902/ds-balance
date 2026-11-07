#import "DSLineChartView.h"
#import "DSBalanceInfo.h"
#import "DSAppearance.h"

@implementation DSLineChartView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _values = @[];
        _timestamps = @[];
        _currencySymbol = @"¥";
        _lineColor = DSAppearance.brandColor;
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)setValues:(NSArray<NSNumber *> *)values {
    _values = [values copy] ?: @[];
    [self setNeedsDisplay];
}

- (void)setTimestamps:(NSArray<NSNumber *> *)timestamps {
    _timestamps = [timestamps copy] ?: @[];
    [self setNeedsDisplay];
}

- (void)setLineColor:(UIColor *)lineColor {
    _lineColor = lineColor ?: DSAppearance.brandColor;
    [self setNeedsDisplay];
}

- (void)setCurrencySymbol:(NSString *)currencySymbol {
    _currencySymbol = [currencySymbol copy] ?: @"¥";
    [self setNeedsDisplay];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    if (width < 40 || height < 40) {
        return;
    }

    CGFloat leftInset = 46;
    CGFloat rightInset = 14;
    CGFloat topInset = 14;
    CGFloat bottomInset = 22;
    CGRect plot = CGRectMake(leftInset, topInset, width - leftInset - rightInset, height - topInset - bottomInset);
    if (plot.size.width < 10 || plot.size.height < 10) {
        return;
    }

    NSArray<NSNumber *> *values = self.values;
    if (values.count == 0) {
        return;
    }

    double minValue = values.firstObject.doubleValue;
    double maxValue = minValue;
    for (NSNumber *number in values) {
        minValue = MIN(minValue, number.doubleValue);
        maxValue = MAX(maxValue, number.doubleValue);
    }
    if (maxValue - minValue < 0.01) {
        maxValue += 1.0;
        minValue -= 1.0;
    }
    double pad = (maxValue - minValue) * 0.18;
    double axisMin = MAX(0.0, minValue - pad);
    double axisMax = maxValue + pad;

    UIFont *axisFont = [UIFont systemFontOfSize:9 weight:UIFontWeightRegular];
    UIColor *axisColor = UIColor.secondaryLabelColor;
    NSDictionary *axisAttributes = @{ NSFontAttributeName: axisFont, NSForegroundColorAttributeName: axisColor };

    // Horizontal guides, dashed, with a value at the left.
    CGContextSaveGState(context);
    CGContextSetStrokeColorWithColor(context, [UIColor.separatorColor colorWithAlphaComponent:0.45].CGColor);
    CGContextSetLineWidth(context, 0.5);
    CGContextSetLineDash(context, 0, (CGFloat[]){ 3, 3 }, 2);
    for (NSInteger i = 0; i <= 2; i++) {
        double value = axisMax - (axisMax - axisMin) * (double)i / 2.0;
        CGFloat y = CGRectGetMaxY(plot) - plot.size.height * (CGFloat)i / 2.0;
        CGContextMoveToPoint(context, CGRectGetMinX(plot), y);
        CGContextAddLineToPoint(context, CGRectGetMaxX(plot), y);
        CGContextStrokePath(context);

        NSString *text = [NSString stringWithFormat:@"%@%@", self.currencySymbol, DSMoneyText(value)];
        CGSize size = [text sizeWithAttributes:axisAttributes];
        [text drawAtPoint:CGPointMake(CGRectGetMinX(plot) - size.width - 6, y - size.height / 2.0)
           withAttributes:axisAttributes];
    }
    CGContextRestoreGState(context);

    // Points mapped into the plot.
    NSUInteger count = values.count;
    double span = axisMax - axisMin;
    NSTimeInterval firstTime = self.timestamps.count == count ? self.timestamps.firstObject.doubleValue : 0;
    NSTimeInterval lastTime = self.timestamps.count == count ? self.timestamps.lastObject.doubleValue : 1;
    NSTimeInterval timeSpan = MAX(lastTime - firstTime, 1);

    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        double ratioX = 0.5;
        if (count > 1) {
            if (self.timestamps.count == count) {
                ratioX = (self.timestamps[i].doubleValue - firstTime) / timeSpan;
            } else {
                ratioX = (double)i / (double)(count - 1);
            }
        }
        double ratioY = (values[i].doubleValue - axisMin) / span;
        CGFloat x = CGRectGetMinX(plot) + plot.size.width * (CGFloat)ratioX;
        CGFloat y = CGRectGetMaxY(plot) - plot.size.height * (CGFloat)ratioY;
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
    }

    CGPoint first = points.firstObject.CGPointValue;
    CGPoint last = points.lastObject.CGPointValue;

    if (points.count > 1) {
        CGMutablePathRef area = CGPathCreateMutable();
        CGPathMoveToPoint(area, NULL, first.x, CGRectGetMaxY(plot));
        for (NSValue *value in points) {
            CGPoint point = value.CGPointValue;
            CGPathAddLineToPoint(area, NULL, point.x, point.y);
        }
        CGPathAddLineToPoint(area, NULL, last.x, CGRectGetMaxY(plot));
        CGPathCloseSubpath(area);

        CGContextSaveGState(context);
        CGContextAddPath(context, area);
        CGContextClip(context);
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[
            (__bridge id)[self.lineColor colorWithAlphaComponent:0.22].CGColor,
            (__bridge id)[self.lineColor colorWithAlphaComponent:0.02].CGColor,
        ];
        CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, NULL);
        CGContextDrawLinearGradient(context, gradient,
                                    CGPointMake(0, CGRectGetMinY(plot)),
                                    CGPointMake(0, CGRectGetMaxY(plot)), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        CGContextRestoreGState(context);
        CGPathRelease(area);

        CGMutablePathRef line = CGPathCreateMutable();
        CGPathMoveToPoint(line, NULL, first.x, first.y);
        for (NSUInteger i = 1; i < points.count; i++) {
            CGPoint point = points[i].CGPointValue;
            CGPathAddLineToPoint(line, NULL, point.x, point.y);
        }
        CGContextAddPath(context, line);
        CGContextSetStrokeColorWithColor(context, self.lineColor.CGColor);
        CGContextSetLineWidth(context, 2.2);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextStrokePath(context);
        CGPathRelease(line);
    }

    CGContextSetFillColorWithColor(context, self.lineColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(last.x - 4.5, last.y - 4.5, 9, 9));
    CGContextSetStrokeColorWithColor(context, UIColor.systemBackgroundColor.CGColor);
    CGContextSetLineWidth(context, 2);
    CGContextStrokeEllipseInRect(context, CGRectMake(last.x - 4.5, last.y - 4.5, 9, 9));

    // Time labels along the bottom.
    if (self.timestamps.count == count && count > 1) {
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
        BOOL sameDay = timeSpan < 24 * 3600;
        formatter.dateFormat = sameDay ? @"HH:mm" : @"M/d";
        NSInteger labelCount = 4;
        for (NSInteger i = 0; i < labelCount; i++) {
            NSTimeInterval time = firstTime + timeSpan * (double)i / (double)(labelCount - 1);
            NSString *text = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:time]];
            CGSize size = [text sizeWithAttributes:axisAttributes];
            CGFloat x = CGRectGetMinX(plot) + plot.size.width * (CGFloat)i / (CGFloat)(labelCount - 1) - size.width / 2.0;
            x = MIN(MAX(x, 0), width - size.width);
            [text drawAtPoint:CGPointMake(x, CGRectGetMaxY(plot) + 6) withAttributes:axisAttributes];
        }
    }
}

@end
