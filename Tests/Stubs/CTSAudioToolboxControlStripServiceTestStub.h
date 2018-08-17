#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioServices.h>

/**
 Stubbed AudioToolbox definitions for testing @c CTSControlStripService.
 */
extern OSStatus AudioServicesCreateSystemSoundID(CFURLRef inFileURL,
                                                 SystemSoundID *outSystemSoundID) __attribute__((weak));

extern void AudioServicesPlaySystemSound(SystemSoundID inSystemSoundID) __attribute__((weak));

/**
 A @c CTSAudioServicesMock object provides Objective-C method bindings between the test runner and OCMockito.
 */
@interface CTSAudioServicesMock : NSObject

- (OSStatus)audioServicesCreateSystemSoundID:(CFURLRef)inFileURL
                            outSystemSoundID:(SystemSoundID *)outSystemSoundID;

- (void)audioServicesPlaySystemSound:(SystemSoundID)inSystemSoundID;

@end
