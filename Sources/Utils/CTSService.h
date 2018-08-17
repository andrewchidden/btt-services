#import <Foundation/Foundation.h>

/**
 Objects that implement @c CTSService should be runnable after initialization.
 */
@protocol CTSService <NSObject>

/// Whether or not the service is running. If the service encounters an error then @c running will be set to @c NO.
@property (nonatomic, assign, readonly, getter=isRunning) BOOL running;

/// Start the service, adding observers and setting status as required.
- (void)start;

@end
