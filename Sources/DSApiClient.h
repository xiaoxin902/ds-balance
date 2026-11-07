#import <Foundation/Foundation.h>
#import "DSBalanceInfo.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DSApiErrorDomain;

typedef NS_ENUM(NSInteger, DSApiErrorCode) {
    DSApiErrorCodeMissingKey = 1,
    DSApiErrorCodeBadKey = 2,
    DSApiErrorCodeNetwork = 3,
    DSApiErrorCodeBadPayload = 4,
    DSApiErrorCodeServer = 5,
    DSApiErrorCodeRateLimited = 6,
};

typedef void (^DSBalanceHandler)(BOOL available, NSArray<DSBalanceInfo *> *infos, NSError *error);

/// The one public endpoint DeepSeek documents for an API key:
/// GET https://api.deepseek.com/user/balance with "Authorization: Bearer &lt;key&gt;".
@interface DSApiClient : NSObject

+ (void)fetchBalanceWithKey:(NSString *)key completion:(DSBalanceHandler)completion;

@end

NS_ASSUME_NONNULL_END
