#import "CTSControlStripService.h"
#import <IOKit/hidsystem/ev_keymap.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

static NSEventModifierFlags const kSmallStepModifierFlags = (NSEventModifierFlagShift | NSEventModifierFlagOption);
static NSString * const kFeedbackSoundFilePath =
    @"/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff";
static NSString * const kSystemPreferencePaneBasePath = @"/System/Library/PreferencePanes/";
static NSString * const kSoundPreferencePaneFileName = @"Sound.prefPane";
static NSString * const kDisplaysPreferencePaneFileName = @"Displays.prefPane";

@interface CTSControlStripService ()

@property (nonatomic, assign, readonly) CTSControlStripControlType controlType;
@property (nonatomic, strong, readonly) NSWorkspace *workspace;
@property (nonatomic, assign, readonly, getter=isShiftPressed) BOOL shiftPressed;
@property (nonatomic, assign, readonly, getter=isOptionPressed) BOOL optionPressed;
@property (nonatomic, assign, readonly) BOOL shouldUseSmallStep;
@property (nonatomic, assign, readonly) BOOL shouldOpenPreferencePane;
@property (nonatomic, assign, readonly, getter=isVolumeControlType) BOOL volumeControlType;
@property (nonatomic, assign, readonly) BOOL shouldPlayFeedbackSound;
@property (nonatomic, assign, readonly) CGKeyCode keyCode;

@end

@implementation CTSControlStripService

@synthesize running = _running;

- (instancetype)initWithControlType:(CTSControlStripControlType)controlType
              volumeFeedbackEnabled:(BOOL)volumeFeedbackEnabled
                      modifierFlags:(NSEventModifierFlags)modifierFlags
                          workspace:(NSWorkspace *)workspace
{
    self = [super init];

    if (self) {
        _controlType = controlType;
        _workspace = workspace;
        _volumeControlType = controlType == CTSControlStripVolumeUpControl
                          || controlType == CTSControlStripVolumeDownControl;

        _shiftPressed = !!(modifierFlags & NSEventModifierFlagShift);
        _optionPressed = !!(modifierFlags & NSEventModifierFlagOption);
        _shouldUseSmallStep = (_optionPressed && _shiftPressed);
        _shouldOpenPreferencePane = (_optionPressed && !_shiftPressed);
        _shouldPlayFeedbackSound = volumeFeedbackEnabled
                                && _volumeControlType
                                && _shiftPressed
                                && !_optionPressed;

        CGKeyCode code = 0;
        if (_volumeControlType) {
            code = (controlType == CTSControlStripVolumeUpControl ? NX_KEYTYPE_SOUND_UP : NX_KEYTYPE_SOUND_DOWN);
        } else {
            if (_shiftPressed && !_optionPressed) {
                code = (controlType == CTSControlStripBrightnessUpControl ? NX_KEYTYPE_ILLUMINATION_UP
                                                                          : NX_KEYTYPE_ILLUMINATION_DOWN);
            } else {
                code = (controlType == CTSControlStripBrightnessUpControl ? NX_KEYTYPE_BRIGHTNESS_UP
                                                                          : NX_KEYTYPE_BRIGHTNESS_DOWN);
            }
        }
        _keyCode = code;
    }

    return self;
}

- (void)start
{
    _running = YES;

    if (self.shouldOpenPreferencePane) {
        NSString * const preferenceName = [self isVolumeControlType] ? kSoundPreferencePaneFileName
                                                                     : kDisplaysPreferencePaneFileName;
        NSString * const preferencePanePath =
            [kSystemPreferencePaneBasePath stringByAppendingPathComponent:preferenceName];
        [self.workspace openFile:preferencePanePath];
    } else {
        [self performKeyPress];
    }

    _running = NO;
}

- (void)performKeyPress
{
    NSEventModifierFlags const smallStepModifierFlags = (self.shouldUseSmallStep ? kSmallStepModifierFlags : 0);

    NSEvent * const keyDownEvent = [NSEvent otherEventWithType:NSEventTypeSystemDefined
                                     location:NSPointFromCGPoint(CGPointZero)
                                modifierFlags:NX_KEYDOWN | smallStepModifierFlags
                                    timestamp:0
                                 windowNumber:0
                                      context:nil
                                      subtype:8
                                        data1:((self.keyCode << 16) | (NX_KEYDOWN << 8))
                                        data2:-1];
    CGEventPost(kCGHIDEventTap, [keyDownEvent CGEvent]);

    usleep(1000); // DRAGON: Not waiting can cause the key press to execute out-of-order and fail.

    NSEvent * const keyUpEvent = [NSEvent otherEventWithType:NSEventTypeSystemDefined
                                     location:NSPointFromCGPoint(CGPointZero)
                                modifierFlags:NX_KEYUP | smallStepModifierFlags
                                    timestamp:0
                                 windowNumber:0
                                      context:nil
                                      subtype:8
                                        data1:((self.keyCode << 16) | (NX_KEYUP << 8))
                                        data2:-1];
    CGEventPost(kCGHIDEventTap, [keyUpEvent CGEvent]);

    usleep(15000); // DRAGON: Not waiting after posting the event can cause the key up to not send.

    if (self.shouldPlayFeedbackSound) {
        NSURL * const audioFileURL = [NSURL fileURLWithPath:kFeedbackSoundFilePath];
        SystemSoundID feedbackSoundID;
        OSStatus err = AudioServicesCreateSystemSoundID((__bridge CFURLRef)audioFileURL, &feedbackSoundID);
        if (err == noErr) {
            AudioServicesPlaySystemSound(feedbackSoundID);
        }
        [NSThread sleepForTimeInterval:0.5];
    } else {
        usleep(15000);
    }
}

@end

NS_ASSUME_NONNULL_END
