#import "DSStore.h"
#import <Security/Security.h>

NSString *const DSDataDidChangeNotification = @"DSDataDidChangeNotification";
NSString *const DSAppearanceDidChangeNotification = @"DSAppearanceDidChangeNotification";
NSString *const DSRefreshRequestedNotification = @"DSRefreshRequestedNotification";
NSString *const DSRefreshSettingsDidChangeNotification = @"DSRefreshSettingsDidChangeNotification";

static NSString *const kKeyAPIKey = @"DSApiKey";
static NSString *const kFallbackAPIKey = @"DSFallbackAPIKey";
static NSString *const kKeyAppearance = @"DSAppearanceMode";
static NSString *const kKeyRefreshOnLaunch = @"DSRefreshOnLaunch";
static NSString *const kKeyRefreshInterval = @"DSRefreshInterval";
static NSString *const kKeyRetryBackoff = @"DSRetryBackoffEnabled";
static NSString *const kKeyRetryBase = @"DSRetryBaseInterval";
static NSString *const kKeyLowAlert = @"DSLowBalanceAlertEnabled";
static NSString *const kKeyAlertOnOpen = @"DSAlertOnOpen";
static NSString *const kKeyThreshold = @"DSLowBalanceThreshold";
static NSString *const kKeyNotifyEnabled = @"DSNotificationsEnabled";
static NSString *const kKeyLowNotified = @"DSLowBalanceNotified";
static NSString *const kKeyLastRefresh = @"DSLastRefreshTime";
static NSString *const kKeySnapshots = @"DSSnapshots";

static const NSUInteger kMaxSnapshots = 800;

@implementation DSStore

+ (instancetype)sharedStore {
    static DSStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [DSStore new];
    });
    return store;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [NSUserDefaults.standardUserDefaults registerDefaults:@{
            kKeyAppearance: @(DSAppearanceModeSystem),
            kKeyRefreshOnLaunch: @YES,
            kKeyRefreshInterval: @(300),
            kKeyRetryBackoff: @YES,
            kKeyRetryBase: @(5),
            kKeyLowAlert: @YES,
            kKeyAlertOnOpen: @YES,
            kKeyThreshold: @10.0,
            kKeyNotifyEnabled: @YES,
            kKeyLowNotified: @NO,
        }];
    }
    return self;
}

#pragma mark - Preferences

- (DSAppearanceMode)appearanceMode {
    NSInteger value = [NSUserDefaults.standardUserDefaults integerForKey:kKeyAppearance];
    if (value < DSAppearanceModeSystem || value > DSAppearanceModeDark) {
        return DSAppearanceModeSystem;
    }
    return (DSAppearanceMode)value;
}

- (void)setAppearanceMode:(DSAppearanceMode)appearanceMode {
    [NSUserDefaults.standardUserDefaults setInteger:appearanceMode forKey:kKeyAppearance];
    [NSNotificationCenter.defaultCenter postNotificationName:DSAppearanceDidChangeNotification object:nil];
}

- (BOOL)refreshOnLaunch {
    return [NSUserDefaults.standardUserDefaults boolForKey:kKeyRefreshOnLaunch];
}

- (void)setRefreshOnLaunch:(BOOL)refreshOnLaunch {
    [NSUserDefaults.standardUserDefaults setBool:refreshOnLaunch forKey:kKeyRefreshOnLaunch];
}

- (NSTimeInterval)refreshInterval {
    NSNumber *number = [NSUserDefaults.standardUserDefaults objectForKey:kKeyRefreshInterval];
    return number ? number.doubleValue : 300;
}

- (void)setRefreshInterval:(NSTimeInterval)refreshInterval {
    if (refreshInterval < 0) {
        refreshInterval = 0;
    }
    [NSUserDefaults.standardUserDefaults setDouble:refreshInterval forKey:kKeyRefreshInterval];
    [NSNotificationCenter.defaultCenter postNotificationName:DSRefreshSettingsDidChangeNotification object:nil];
}

- (BOOL)retryBackoffEnabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:kKeyRetryBackoff];
}

- (void)setRetryBackoffEnabled:(BOOL)enabled {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:kKeyRetryBackoff];
    [NSNotificationCenter.defaultCenter postNotificationName:DSRefreshSettingsDidChangeNotification object:nil];
}

- (NSTimeInterval)retryBaseInterval {
    NSNumber *number = [NSUserDefaults.standardUserDefaults objectForKey:kKeyRetryBase];
    double value = number ? number.doubleValue : 5;
    return value >= 1 ? value : 5;
}

- (void)setRetryBaseInterval:(NSTimeInterval)retryBaseInterval {
    if (retryBaseInterval < 1) {
        retryBaseInterval = 1;
    }
    [NSUserDefaults.standardUserDefaults setDouble:retryBaseInterval forKey:kKeyRetryBase];
}

- (BOOL)lowBalanceAlertEnabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:kKeyLowAlert];
}

- (void)setLowBalanceAlertEnabled:(BOOL)enabled {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:kKeyLowAlert];
}

- (double)lowBalanceThreshold {
    NSNumber *number = [NSUserDefaults.standardUserDefaults objectForKey:kKeyThreshold];
    double value = number ? number.doubleValue : 10.0;
    return value >= 0 ? value : 10.0;
}

- (void)setLowBalanceThreshold:(double)threshold {
    if (threshold < 0) {
        threshold = 0;
    }
    [NSUserDefaults.standardUserDefaults setDouble:threshold forKey:kKeyThreshold];
}

- (BOOL)notificationsEnabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:kKeyNotifyEnabled];
}

- (void)setNotificationsEnabled:(BOOL)enabled {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:kKeyNotifyEnabled];
}

- (BOOL)alertOnOpen {
    return [NSUserDefaults.standardUserDefaults boolForKey:kKeyAlertOnOpen];
}

- (void)setAlertOnOpen:(BOOL)alertOnOpen {
    [NSUserDefaults.standardUserDefaults setBool:alertOnOpen forKey:kKeyAlertOnOpen];
}

- (BOOL)lowBalanceNotified {
    return [NSUserDefaults.standardUserDefaults boolForKey:kKeyLowNotified];
}

- (void)setLowBalanceNotified:(BOOL)notified {
    [NSUserDefaults.standardUserDefaults setBool:notified forKey:kKeyLowNotified];
}

- (NSTimeInterval)lastRefreshTime {
    return [NSUserDefaults.standardUserDefaults doubleForKey:kKeyLastRefresh];
}

- (void)setLastRefreshTime:(NSTimeInterval)lastRefreshTime {
    [NSUserDefaults.standardUserDefaults setDouble:lastRefreshTime forKey:kKeyLastRefresh];
}

#pragma mark - API key (keychain with a defaults fallback)

- (NSString *)apiKey {
    NSString *value = [self keychainValue];
    if (value.length > 0) {
        return value;
    }
    return [NSUserDefaults.standardUserDefaults stringForKey:kFallbackAPIKey];
}

- (void)setApiKey:(NSString *)apiKey {
    NSString *trimmed = [apiKey stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        [self deleteKeychainValue];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kFallbackAPIKey];
    } else {
        // The keychain is the primary copy. A re-signed build gets a new
        // keychain access group and cannot read the old one, so a second copy
        // lives outside it; this is a jailbroken device, no stronger promise.
        if (![self setKeychainValue:trimmed]) {
            NSLog(@"[DSBalance] keychain refused the API key, keeping the local copy only");
        }
        [NSUserDefaults.standardUserDefaults setObject:trimmed forKey:kFallbackAPIKey];
    }
    [NSUserDefaults.standardUserDefaults synchronize];
    [NSNotificationCenter.defaultCenter postNotificationName:DSDataDidChangeNotification object:nil];
}

- (NSMutableDictionary *)keychainQuery {
    NSString *service = NSBundle.mainBundle.bundleIdentifier ?: @"bc.8848.dsbalance";
    return [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: @"deepseek-api-key",
    } mutableCopy];
}

- (NSString *)keychainValue {
    NSMutableDictionary *query = [self keychainQuery];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || result == NULL) {
        return nil;
    }
    NSData *data = (__bridge_transfer NSData *)result;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (BOOL)setKeychainValue:(NSString *)value {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) {
        return NO;
    }
    NSMutableDictionary *query = [self keychainQuery];
    NSDictionary *attributes = @{ (__bridge id)kSecValueData: data };
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        [query addEntriesFromDictionary:attributes];
        query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    if (status != errSecSuccess) {
        NSLog(@"[DSBalance] keychain write failed: %d", (int)status);
        return NO;
    }
    return YES;
}

- (void)deleteKeychainValue {
    NSMutableDictionary *query = [self keychainQuery];
    SecItemDelete((__bridge CFDictionaryRef)query);
}

#pragma mark - Snapshots

- (NSArray<NSDictionary *> *)snapshots {
    id value = [NSUserDefaults.standardUserDefaults arrayForKey:kKeySnapshots];
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

- (void)addSnapshotWithInfo:(DSBalanceInfo *)info {
    if (!info) {
        return;
    }
    NSMutableArray *snapshots = [self.snapshots mutableCopy] ?: [NSMutableArray array];

    NSDictionary *last = snapshots.lastObject;
    if (last) {
        double lastTotal = [last[@"b"] doubleValue];
        double lastTime = [last[@"t"] doubleValue];
        // Same money within five minutes is not a new data point.
        if (fabs(lastTotal - info.total) < 0.005 && (NSDate.date.timeIntervalSince1970 - lastTime) < 300) {
            return;
        }
    }

    [snapshots addObject:@{
        @"t": @(NSDate.date.timeIntervalSince1970),
        @"b": @(info.total),
        @"g": @(info.granted),
        @"p": @(info.toppedUp),
        @"c": info.currency ?: @"CNY",
    }];

    if (snapshots.count > kMaxSnapshots) {
        [snapshots removeObjectsInRange:NSMakeRange(0, snapshots.count - kMaxSnapshots)];
    }
    [NSUserDefaults.standardUserDefaults setObject:snapshots forKey:kKeySnapshots];
    [NSNotificationCenter.defaultCenter postNotificationName:DSDataDidChangeNotification object:nil];
}

- (void)clearSnapshots {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kKeySnapshots];
    [NSNotificationCenter.defaultCenter postNotificationName:DSDataDidChangeNotification object:nil];
}

@end
