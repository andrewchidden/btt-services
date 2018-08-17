#import <Foundation/Foundation.h>
#import <CoreAudio/AudioHardwareBase.h>
#import <CoreAudio/AudioHardware.h>

/**
 Stubbed AudioToolbox definitions for testing @c CTSVolumeService.
 */

CF_ENUM(AudioObjectPropertySelector)
{
    kAudioHardwareServiceProperty_ServiceRestarted              = 'srst',
    kAudioHardwareServiceDeviceProperty_VirtualMasterVolume     = 'vmvc',
    kAudioHardwareServiceDeviceProperty_VirtualMasterBalance    = 'vmbc',
};

extern OSStatus AudioObjectAddPropertyListener(AudioObjectID inObjectID,
                                               const AudioObjectPropertyAddress *inAddress,
                                               AudioObjectPropertyListenerProc inListener,
                                               void * __nullable inClientData) __attribute__((weak));

extern OSStatus AudioHardwareServiceAddPropertyListener(AudioObjectID inObjectID,
                                                        const AudioObjectPropertyAddress *inAddress,
                                                        AudioObjectPropertyListenerProc inListener,
                                                        void *inClientData) __attribute__((weak));

extern OSStatus AudioHardwareServiceRemovePropertyListener(AudioObjectID inObjectID,
                                                           const AudioObjectPropertyAddress *inAddress,
                                                           AudioObjectPropertyListenerProc inListener,
                                                           void *inClientData) __attribute__((weak));

extern OSStatus AudioHardwareServiceGetPropertyData(AudioObjectID inObjectID,
                                                    const AudioObjectPropertyAddress *inAddress,
                                                    UInt32 inQualifierDataSize,
                                                    const void *inQualifierData,
                                                    UInt32 *ioDataSize,
                                                    void *outData) __attribute__((weak));

/**
 A @c CTSAudioHardwareServiceMock object provides Objective-C method bindings between the test runner and OCMockito.
 */
@interface CTSAudioHardwareServiceMock : NSObject

- (OSStatus)audioObjectAddPropertyListener:(AudioObjectID)inObjectID
                                 inAddress:(const AudioObjectPropertyAddress *)inAddress
                                inListener:(AudioObjectPropertyListenerProc)inListener
                              inClientData:(void *)inClientData;

- (OSStatus)audioHardwareServiceAddPropertyListener:(AudioObjectID)inObjectID
                                          inAddress:(const AudioObjectPropertyAddress *)inAddress
                                         inListener:(AudioObjectPropertyListenerProc)inListener
                                       inClientData:(void *)inClientData;

- (OSStatus)audioHardwareServiceRemovePropertyListener:(AudioObjectID)inObjectID
                                             inAddress:(const AudioObjectPropertyAddress *)inAddress
                                            inListener:(AudioObjectPropertyListenerProc)inListener
                                          inClientData:(void *)inClientData;

- (OSStatus)audioHardwareServiceGetPropertyData:(AudioObjectID)inObjectID
                                      inAddress:(const AudioObjectPropertyAddress *)inAddress
                            inQualifierDataSize:(UInt32)inQualifierDataSize
                                inQualifierData:(const void *)inQualifierData
                                     ioDataSize:(UInt32 *)ioDataSize
                                        outData:(void *)outData;

@end
