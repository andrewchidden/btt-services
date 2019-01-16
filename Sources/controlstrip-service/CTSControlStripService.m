#import "CTSControlStripService.h"
#import <IOKit/hidsystem/ev_keymap.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface CTSControlStripService ()

@property (nonatomic, assign, readonly) CTSControlStripControlType controlType;
@property (nonatomic, strong, readonly) NSWorkspace *workspace;
@property (nonatomic, assign, readonly, getter=isShiftPressed) BOOL shiftPressed;
@property (nonatomic, assign, readonly, getter=isOptionPressed) BOOL optionPressed;
@property (nonatomic, assign, readonly) BOOL shouldPerformModifiedKeyPress;
@property (nonatomic, assign, readonly, getter=isVolumeControlType) BOOL volumeControlType;
@property (nonatomic, assign, readonly) CGKeyCode keyCode;
@property (nonatomic, assign, readwrite) io_connect_t hidConnection;

@end

@implementation CTSControlStripService

@synthesize running = _running;

- (instancetype)initWithControlType:(CTSControlStripControlType)controlType
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

        CGKeyCode code = 0;
        if (_volumeControlType) {
            code = (controlType == CTSControlStripVolumeUpControl ? NX_KEYTYPE_SOUND_UP : NX_KEYTYPE_SOUND_DOWN);
        } else {
            if (_shiftPressed && !_optionPressed) {
                code = (controlType == CTSControlStripBrightnessUpControl ? NX_KEYTYPE_ILLUMINATION_UP
                                                                          : NX_KEYTYPE_ILLUMINATION_DOWN);
                _shouldPerformModifiedKeyPress = YES;
            } else {
                code = (controlType == CTSControlStripBrightnessUpControl ? NX_KEYTYPE_BRIGHTNESS_UP
                                                                          : NX_KEYTYPE_BRIGHTNESS_DOWN);
            }
        }
        _keyCode = code;

        mach_port_t masterPort;
        io_service_t service = 0;
        kern_return_t returnValue;

        returnValue = IOMasterPort(bootstrap_port, &masterPort);
        if (returnValue != KERN_SUCCESS) {
            return nil;
        }

        service = IOServiceGetMatchingService(masterPort, IOServiceMatching(kIOHIDSystemClass));
        if (service == 0) {
            return nil;
        }

        returnValue = IOServiceOpen(service, mach_task_self(), kIOHIDParamConnectType, &_hidConnection);
        if (returnValue != KERN_SUCCESS) {
            return nil;
        }
    }

    return self;
}

- (void)start
{
    _running = YES;
    if (self.shouldPerformModifiedKeyPress) {
        [self performModifiedKeyPress];
    } else {
        [self performKeyPress];
    }
    _running = NO;
}

- (void)performKeyPress
{
    NXEventData event = {0};
    IOGPoint point = {0};
    kern_return_t returnValue;

    event.compound.subType = NX_SUBTYPE_AUX_CONTROL_BUTTONS;
    event.compound.misc.L[0] = (NX_KEYDOWN << 8) | (self.keyCode << 16);
    returnValue = IOHIDPostEvent(self.hidConnection,
                                 NX_SYSDEFINED,
                                 point,
                                 &event,
                                 kNXEventDataVersion,
                                 0,
                                 0);
    if (returnValue != KERN_SUCCESS) {
        return;
    }

    event.compound.subType = NX_SUBTYPE_AUX_CONTROL_BUTTONS;
    event.compound.misc.L[0] = (NX_KEYUP << 8) | (self.keyCode << 16);
    returnValue = IOHIDPostEvent(self.hidConnection,
                                 NX_SYSDEFINED,
                                 point,
                                 &event,
                                 kNXEventDataVersion,
                                 0,
                                 0);
    if (returnValue != KERN_SUCCESS) {
        return;
    }
}

- (void)performModifiedKeyPress
{
    NSEvent * const keyDownEvent = [NSEvent otherEventWithType:NSEventTypeSystemDefined
                                                      location:NSPointFromCGPoint(CGPointZero)
                                                 modifierFlags:NX_KEYDOWN
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
                                               modifierFlags:NX_KEYUP
                                                   timestamp:0
                                                windowNumber:0
                                                     context:nil
                                                     subtype:8
                                                       data1:((self.keyCode << 16) | (NX_KEYUP << 8))
                                                       data2:-1];
    CGEventPost(kCGHIDEventTap, [keyUpEvent CGEvent]);

    usleep(15000);
}

@end

NS_ASSUME_NONNULL_END
