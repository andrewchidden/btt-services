#import "CTSBetterTouchToolWebServerConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CTSBetterTouchToolWebServerConfiguration

- (instancetype)initWithURL:(NSURL * const)URL sharedSecret:(nullable NSString * const)sharedSecret
{
    self = [super init];

    if (self) {
        _URL = URL;
        _sharedSecret = sharedSecret;
    }

    return self;
}

@end

NS_ASSUME_NONNULL_END
