#import "DSBalanceInfo.h"

static double DSNumberFromObject(id object) {
    if ([object isKindOfClass:NSNumber.class]) {
        return [(NSNumber *)object doubleValue];
    }
    if ([object isKindOfClass:NSString.class]) {
        return [(NSString *)object doubleValue];
    }
    return 0;
}

@implementation DSBalanceInfo

+ (instancetype)infoFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return nil;
    }
    NSString *currency = dictionary[@"currency"];
    if (![currency isKindOfClass:NSString.class] || currency.length == 0) {
        currency = @"CNY";
    }
    DSBalanceInfo *info = [DSBalanceInfo new];
    info.currency = currency;
    info.total = DSNumberFromObject(dictionary[@"total_balance"]);
    info.granted = DSNumberFromObject(dictionary[@"granted_balance"]);
    info.toppedUp = DSNumberFromObject(dictionary[@"topped_up_balance"]);
    return info;
}

- (NSString *)currencySymbol {
    if ([self.currency caseInsensitiveCompare:@"CNY"] == NSOrderedSame) {
        return @"¥";
    }
    if ([self.currency caseInsensitiveCompare:@"USD"] == NSOrderedSame) {
        return @"$";
    }
    return [self.currency stringByAppendingString:@" "];
}

- (NSString *)currencyTitle {
    if ([self.currency caseInsensitiveCompare:@"CNY"] == NSOrderedSame) {
        return @"人民币";
    }
    if ([self.currency caseInsensitiveCompare:@"USD"] == NSOrderedSame) {
        return @"美元";
    }
    return self.currency;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<DSBalanceInfo %@ total=%.2f granted=%.2f toppedUp=%.2f>",
                                      self.currency, self.total, self.granted, self.toppedUp];
}

@end

NSString *DSMoneyText(double value) {
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.minimumFractionDigits = 2;
        formatter.maximumFractionDigits = 2;
        formatter.usesGroupingSeparator = YES;
        formatter.groupingSeparator = @",";
        formatter.decimalSeparator = @".";
    });
    NSString *text = [formatter stringFromNumber:@(value)];
    return text ?: [NSString stringWithFormat:@"%.2f", value];
}

NSString *DSDeltaText(double delta) {
    if (fabs(delta) < 0.005) {
        return @"±0.00";
    }
    return [NSString stringWithFormat:@"%@%@", delta > 0 ? @"+" : @"-", DSMoneyText(fabs(delta))];
}
