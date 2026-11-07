#import "DSLineChartView.h"
#import "DSAppearance.h"

@implementation DSLineChartView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _values = @[];
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

- (void)setLineColor:(UIColor *)lineColor {
    _lineColor = lineColor ?: DSAppearance.brandColor;
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

    CGRect bounds = self.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    if (width < 2 || height < 2) {
        return;
    }

    CGFloat topInset = 10;
    CGFloat bottomInset = 10;
    CGRect plot = CGRectMake(0, topInset, width, height - topInset - bottomInset);
    if (plot.size.height < 4) {
        return;
    }

    // Horizontal guide lines.
    CGContextSetStrokeColorWithColor(context, [UIColor.separatorColor colorWithAlphaComponent:0.35].CGColor);
    CGContextSetLineWidth(context, 0.5);
    for (NSInteger i = 0; i <= 3; i++) {
        CGFloat y = CGRectGetMinY(plot) + plot.size.height * (CGFloat)i / 3.0;
        CGContextMoveToPoint(context, 0, y);
        CGContextAddLineToPoint(context, width, y);
    }
    CGContextStrokePath(context);

    NSArray<NSNumber *> *values = self.values;
    if (values.count == 0) {
        return;
    }

    double minValue = values.firstObject.doubleValue;
    double maxValue = minValue;
    for (NSNumber *number in values) {
        double value = number.doubleValue;
        minValue = MIN(minValue, value);
        maxValue = MAX(maxValue, value);
    }

    CGFloat verticalPad = plot.size.height * 0.12;
    CGFloat usableHeight = MAX(plot.size.height - verticalPad * 2, 1.0);
    double span = maxValue - minValue;

    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:values.count];
    NSUInteger count = values.count;
    for (NSUInteger i = 0; i < count; i++) {
        CGFloat x = count > 1 ? width * (CGFloat)i / (CGFloat)(count - 1) : width * 0.5;
        double value = values[i].doubleValue;
        CGFloat ratio = span > 0.0001 ? (CGFloat)((value - minValue) / span) : 0.5;
        CGFloat y = CGRectGetMinY(plot) + verticalPad + usableHeight * (1.0 - ratio);
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
    }

    CGPoint first = points.firstObject.CGPointValue;
    CGPoint last = points.lastObject.CGPointValue;
    CGFloat baseline = CGRectGetMaxY(plot);

    if (points.count > 1) {
        // Filled area under the line.
        CGMutablePathRef area = CGPathCreateMutable();
        CGPathMoveToPoint(area, NULL, first.x, baseline);
        for (NSValue *value in points) {
            CGPoint point = value.CGPointValue;
            CGPathAddLineToPoint(area, NULL, point.x, point.y);
        }
        CGPathAddLineToPoint(area, NULL, last.x, baseline);
        CGPathCloseSubpath(area);

        CGContextSaveGState(context);
        CGContextAddPath(context, area);
        CGContextClip(context);

        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        UIColor *lineColor = self.lineColor;
        CGFloat alpha = 0.28;
        NSArray *colors = @[
            (__bridge id)[lineColor colorWithAlphaComponent:alpha].CGColor,
            (__bridge id)[lineColor colorWithAlphaComponent:0.02].CGColor,
        ];
        CGGradientRef gradient = CGGradientCreateWithColors(space,
            (__bridge CFArrayRef)colors, NULL);
        CGContextDrawLinearGradient(context, gradient,
            CGPointMake(0, CGRectGetMinY(plot)),
            CGPointMake(0, baseline), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        CGContextRestoreGState(context);
        CGPathRelease(area);

        // The line itself.
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

    // Marker on the newest point.
    CGContextSetFillColorWithColor(context, self.lineColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(last.x - 4, last.y - 4, 8, 8));
    CGContextSetStrokeColorWithColor(context, UIColor.systemBackgroundColor.CGColor);
    CGContextSetLineWidth(context, 2);
    CGContextStrokeEllipseInRect(context, CGRectMake(last.x - 4, last.y - 4, 8, 8));
}

@end
