#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "CTSService.h"

NS_ASSUME_NONNULL_BEGIN

/// The type control action to perform.
typedef NS_ENUM(NSUInteger, CTSControlStripControlType)
{
    CTSControlStripNoControl = 0,

    CTSControlStripVolumeUpControl = 1,
    CTSControlStripVolumeDownControl,

    CTSControlStripBrightnessUpControl = 101,
    CTSControlStripBrightnessDownControl,
};

@interface CTSControlStripService : NSObject <CTSService>

/**
 Create a service.

 @param controlType The type of control action to perform.
 @param volumeFeedbackEnabled Whether or not volume feedback is enabled. If enabled, feedback sound will be played on
 volume change.
 @param modifierFlags The current set of keyed-down modifier flags.
 @param workspace The workspace object to use for opening preference panes in System Preferences.
 @return A new control strip service instance.
 */
- (instancetype)initWithControlType:(CTSControlStripControlType)controlType
              volumeFeedbackEnabled:(BOOL)volumeFeedbackEnabled
                      modifierFlags:(NSEventModifierFlags)modifierFlags
                          workspace:(NSWorkspace *)workspace NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
