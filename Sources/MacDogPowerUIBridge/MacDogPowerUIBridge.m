#import "MacDogPowerUIBridge.h"
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString * const MDChargeLimitBridgeErrorDomain = @"MacDogChargeLimitBridge";

static NSError *MDChargeLimitError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:MDChargeLimitBridgeErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static Class MDChargeLimitClientClass(NSError **error) {
    static dispatch_once_t onceToken;
    static BOOL didLoadPowerUI = NO;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/PowerUI.framework/PowerUI", RTLD_NOW);
        didLoadPowerUI = handle != NULL;
    });

    if (!didLoadPowerUI) {
        if (error) {
            *error = MDChargeLimitError(1, @"PowerUI framework를 불러오지 못했습니다.");
        }
        return Nil;
    }

    Class clientClass = NSClassFromString(@"PowerUISmartChargeClient");
    if (!clientClass) {
        if (error) {
            *error = MDChargeLimitError(2, @"PowerUI 충전 제어 클라이언트를 찾지 못했습니다.");
        }
        return Nil;
    }
    return clientClass;
}

static id MDChargeLimitClient(NSError **error) {
    Class clientClass = MDChargeLimitClientClass(error);
    if (!clientClass) { return nil; }

    id allocated = ((id(*)(id, SEL))objc_msgSend)(clientClass, sel_registerName("alloc"));
    id client = ((id(*)(id, SEL, id))objc_msgSend)(allocated, NSSelectorFromString(@"initWithClientName:"), @"MacDog");
    if (!client && error) {
        *error = MDChargeLimitError(3, @"PowerUI 충전 제어 클라이언트를 초기화하지 못했습니다.");
    }
    return client;
}

BOOL MDChargeLimitIsSupported(NSError **error) {
    id client = MDChargeLimitClient(error);
    if (!client) { return NO; }

    SEL selector = NSSelectorFromString(@"isMCLSupported");
    if (![client respondsToSelector:selector]) {
        if (error) {
            *error = MDChargeLimitError(4, @"충전 한도 지원 여부를 확인할 수 없습니다.");
        }
        return NO;
    }

    return ((BOOL(*)(id, SEL))objc_msgSend)(client, selector);
}

NSArray<NSNumber *> *MDChargeLimitAvailableLimits(NSError **error) {
    id client = MDChargeLimitClient(error);
    if (!client) { return nil; }

    SEL selector = NSSelectorFromString(@"availableChargeLimitsWithError:");
    if (![client respondsToSelector:selector]) {
        if (error) {
            *error = MDChargeLimitError(5, @"사용 가능한 충전 한도 목록을 확인할 수 없습니다.");
        }
        return nil;
    }

    return ((NSArray<NSNumber *> *(*)(id, SEL, NSError **))objc_msgSend)(client, selector, error);
}

NSInteger MDChargeLimitCurrentLimit(NSError **error) {
    id client = MDChargeLimitClient(error);
    if (!client) { return -1; }

    SEL selector = NSSelectorFromString(@"getMCLLimitWithError:");
    if (![client respondsToSelector:selector]) {
        if (error) {
            *error = MDChargeLimitError(6, @"현재 충전 한도를 확인할 수 없습니다.");
        }
        return -1;
    }

    unsigned char limit = ((unsigned char(*)(id, SEL, NSError **))objc_msgSend)(client, selector, error);
    if (error && *error) { return -1; }
    return (NSInteger)limit;
}

BOOL MDChargeLimitSetLimit(NSInteger limit, NSError **error) {
    id client = MDChargeLimitClient(error);
    if (!client) { return NO; }

    SEL selector = NSSelectorFromString(@"setMCLLimit:error:");
    if (![client respondsToSelector:selector]) {
        if (error) {
            *error = MDChargeLimitError(7, @"충전 한도를 변경할 수 없습니다.");
        }
        return NO;
    }

    return ((BOOL(*)(id, SEL, unsigned char, NSError **))objc_msgSend)(client, selector, (unsigned char)limit, error);
}
