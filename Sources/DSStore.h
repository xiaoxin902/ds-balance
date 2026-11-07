#import <Foundation/Foundation.h>
#import "DSBalanceInfo.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DSDataDidChangeNotification;
extern NSString *const DSAppearanceDidChangeNotification;
/// Posted after the API key changes, so the balance screen refreshes at once.
extern NSString *const DSRefreshRequestedNotification;

typedef NS_ENUM(NSInteger, DSAppearanceMode) {
    DSAppearanceModeSystem = 0,
    DSAppearanceModeLight = 1,
    DSAppearanceModeDark = 2,
};

/// Preferences, the API key and the balance snapshots this app samples itself.
@interface DSStore : NSObject

+ (instancetype)sharedStore;

/// Stored in the keychain; falls back to defaults where the keychain refuses
/// an ad-hoc signed app.
@property (nonatomic, copy, nullable) NSString *apiKey;

@property (nonatomic, assign) DSAppearanceMode appearanceMode;
@property (nonatomic, assign) BOOL refreshOnLaunch;
@property (nonatomic, assign) BOOL lowBalanceAlertEnabled;
@property (nonatomic, assign) double lowBalanceThreshold;
@property (nonatomic, assign) BOOL notificationsEnabled;
/// A low-balance notification already went out for the current dip.
@property (nonatomic, assign) BOOL lowBalanceNotified;

/// Newest last. Each entry: t (double), b (double), g (double), p (double), c (string).
@property (nonatomic, readonly) NSArray<NSDictionary *> *snapshots;

- (void)addSnapshotWithInfo:(DSBalanceInfo *)info;
- (void)clearSnapshots;

@end

NS_ASSUME_NONNULL_END
