#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One entry of "balance_infos" from GET /user/balance.
@interface DSBalanceInfo : NSObject

@property (nonatomic, copy) NSString *currency;
@property (nonatomic, assign) double total;
@property (nonatomic, assign) double granted;
@property (nonatomic, assign) double toppedUp;

/// "¥" for CNY, "$" for USD, otherwise "&lt;CODE&gt; " .
@property (nonatomic, readonly) NSString *currencySymbol;
/// "人民币" / "美元" / the raw code.
@property (nonatomic, readonly) NSString *currencyTitle;

+ (nullable instancetype)infoFromDictionary:(NSDictionary *)dictionary;

@end

/// Money text with grouping: 1,234.56
extern NSString *DSMoneyText(double value);
/// "-12.34" / "+100.00" / "±0.00" for a delta between snapshots.
extern NSString *DSDeltaText(double delta);

NS_ASSUME_NONNULL_END
