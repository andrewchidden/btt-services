#import "CTSService.h"

@class CTSBetterTouchToolWebServerConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface CTSVolumeService : NSObject <CTSService>

/**
 Create a service.

 @param statusFilePath The file path to save the latest event status message. Intermediary directories must exist.
 @param URLSession The URL session to use when pushing requests to BetterTouchTool.
 @param widgetUUID An optional widget UUID to push refresh updates after an event changes. If nil, no pushes occur.
 @param webServerConfiguration The optional BetterTouchTool web server configuration object. If nil, no pushes occur.
 @param volumeThresholds An optional set of volume thresholds to check when handling change events. If nil or empty, all
 volume change events are handled and pushed to BetterTouchTool.
 @return A new volume service instance.
 */
- (instancetype)initWithStatusFilePath:(NSString * const)statusFilePath
                            URLSession:(NSURLSession * const)URLSession
                            widgetUUID:(nullable NSString * const)widgetUUID
                webServerConfiguration:(nullable CTSBetterTouchToolWebServerConfiguration * const)webServerConfiguration
                      volumeThresholds:(nullable NSArray<NSNumber *> * const)volumeThresholds
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
