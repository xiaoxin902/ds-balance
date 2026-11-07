#import "DSApiClient.h"

NSString *const DSApiErrorDomain = @"DSApiErrorDomain";

static NSError *DSMakeError(DSApiErrorCode code, NSString *message) {
    return [NSError errorWithDomain:DSApiErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message ?: @"未知错误" }];
}

@implementation DSApiClient

+ (void)fetchBalanceWithKey:(NSString *)key completion:(DSBalanceHandler)completion {
    if (!completion) {
        return;
    }
    NSString *trimmed = [key stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO, @[], DSMakeError(DSApiErrorCodeMissingKey, @"还没有填写 API Key"));
        });
        return;
    }

    NSURL *url = [NSURL URLWithString:@"https://api.deepseek.com/user/balance"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 20;
    [request setValue:[@"Bearer " stringByAppendingString:trimmed] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"DSBalance/1.0 (iOS)" forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        void (^finish)(BOOL, NSArray<DSBalanceInfo *> *, NSError *) = ^(BOOL available, NSArray *infos, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(available, infos ?: @[], err);
            });
        };

        if (error) {
            NSError *mapped = error;
            if ([error.domain isEqualToString:NSURLErrorDomain]) {
                NSString *message = @"网络请求失败";
                switch (error.code) {
                    case NSURLErrorNotConnectedToInternet:
                        message = @"设备未联网";
                        break;
                    case NSURLErrorTimedOut:
                        message = @"请求超时，请稍后重试";
                        break;
                    case NSURLErrorCannotFindHost:
                    case NSURLErrorCannotConnectToHost:
                        message = @"无法连接 api.deepseek.com";
                        break;
                    case NSURLErrorSecureConnectionFailed:
                    case NSURLErrorServerCertificateUntrusted:
                        message = @"安全连接失败";
                        break;
                    default:
                        message = error.localizedDescription ?: message;
                        break;
                }
                mapped = DSMakeError(DSApiErrorCodeNetwork, message);
            }
            finish(NO, @[], mapped);
            return;
        }

        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        NSInteger status = http ? http.statusCode : 0;

        id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;

        if (status == 401 || status == 403) {
            finish(NO, @[], DSMakeError(DSApiErrorCodeBadKey, @"API Key 无效或没有访问权限"));
            return;
        }
        if (status == 402) {
            finish(NO, @[], DSMakeError(DSApiErrorCodeServer, @"账户余额不足，服务已停用"));
            return;
        }
        if (status == 429) {
            finish(NO, @[], DSMakeError(DSApiErrorCodeRateLimited, @"请求过于频繁（HTTP 429），请稍后再试"));
            return;
        }
        if (status < 200 || status >= 300) {
            NSString *serverMessage = nil;
            if ([json isKindOfClass:NSDictionary.class]) {
                id errObject = json[@"error"];
                if ([errObject isKindOfClass:NSDictionary.class] && [errObject[@"message"] isKindOfClass:NSString.class]) {
                    serverMessage = errObject[@"message"];
                }
            }
            NSString *message = serverMessage.length
                ? [NSString stringWithFormat:@"服务返回错误（HTTP %ld）：%@", (long)status, serverMessage]
                : [NSString stringWithFormat:@"服务返回 HTTP %ld", (long)status];
            finish(NO, @[], DSMakeError(DSApiErrorCodeServer, message));
            return;
        }

        if (![json isKindOfClass:NSDictionary.class]) {
            finish(NO, @[], DSMakeError(DSApiErrorCodeBadPayload, @"返回数据格式无法识别"));
            return;
        }

        BOOL available = YES;
        id availableObject = json[@"is_available"];
        if ([availableObject isKindOfClass:NSNumber.class]) {
            available = [availableObject boolValue];
        }

        NSMutableArray<DSBalanceInfo *> *infos = [NSMutableArray array];
        id balanceInfos = json[@"balance_infos"];
        if ([balanceInfos isKindOfClass:NSArray.class]) {
            for (id item in (NSArray *)balanceInfos) {
                DSBalanceInfo *info = [DSBalanceInfo infoFromDictionary:item];
                if (info) {
                    [infos addObject:info];
                }
            }
        }

        if (infos.count == 0) {
            finish(NO, @[], DSMakeError(DSApiErrorCodeBadPayload, @"返回数据里没有余额信息"));
            return;
        }

        finish(available, infos, nil);
    }];
    [task resume];
}

@end
