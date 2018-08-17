#import <Foundation/Foundation.h>

@class CTSBetterTouchToolWebServerConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (CTSBetterTouchToolWebServerEndpoint)

/**
 Create a BetterTouchTool web server URL.

 @param webServerConfiguration A BetterTouchTool web server configuration object.
 @param endpoint A path to the BetterTouchTool web server endpoint.
 @param queryParameters An optional array of GET query parameters in the form `key=value`.
 @return A new @c NSURL instance.
 */
+ (NSURL *)cts_URLWithWebServerConfiguration:(CTSBetterTouchToolWebServerConfiguration * const)webServerConfiguration
                                endpoint:(NSString * const)endpoint
                         queryParameters:(nullable NSArray<NSString *> * const)queryParameters;

@end

NS_ASSUME_NONNULL_END
