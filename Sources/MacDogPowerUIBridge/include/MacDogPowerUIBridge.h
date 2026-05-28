#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT BOOL MDChargeLimitIsSupported(NSError **error);
FOUNDATION_EXPORT NSArray<NSNumber *> * _Nullable MDChargeLimitAvailableLimits(NSError **error);
FOUNDATION_EXPORT NSInteger MDChargeLimitCurrentLimit(NSError **error);
FOUNDATION_EXPORT BOOL MDChargeLimitSetLimit(NSInteger limit, NSError **error);

NS_ASSUME_NONNULL_END
