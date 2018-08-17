#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 A @c CTSBetterTouchToolWebServerConfiguration object holds information used to connect to BetterTouchTool's web server.
 */
@interface CTSBetterTouchToolWebServerConfiguration : NSObject

/// Create a new configuration.
- (instancetype)initWithURL:(NSURL * const)URL sharedSecret:(nullable NSString * const)sharedSecret
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// The base URL to BetterTouchTool's web server, e.g. `http://127.0.0.1:12345`
@property (nonatomic, strong, readonly) NSURL *URL;

/// The optional shared secret to authenticate with BetterTouchTool's web server.
@property (nonatomic, strong, readonly, nullable) NSString *sharedSecret;

@end

NS_ASSUME_NONNULL_END
