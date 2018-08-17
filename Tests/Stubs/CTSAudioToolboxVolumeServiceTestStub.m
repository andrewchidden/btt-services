#import "CTSAudioToolboxVolumeServiceTestStub.h"

OSStatus AudioObjectAddPropertyListener(AudioObjectID inObjectID,
                                               const AudioObjectPropertyAddress *inAddress,
                                               AudioObjectPropertyListenerProc inListener,
                                               void * __nullable inClientData)
{
    return noErr;
}

OSStatus AudioHardwareServiceAddPropertyListener(AudioObjectID inObjectID,
                                                        const AudioObjectPropertyAddress *inAddress,
                                                        AudioObjectPropertyListenerProc inListener,
                                                        void *inClientData)
{
    return noErr;
}

OSStatus AudioHardwareServiceRemovePropertyListener(AudioObjectID inObjectID,
                                                           const AudioObjectPropertyAddress *inAddress,
                                                           AudioObjectPropertyListenerProc inListener,
                                                           void *inClientData)
{
    return noErr;
}

OSStatus AudioHardwareServiceGetPropertyData(AudioObjectID inObjectID,
                                                    const AudioObjectPropertyAddress *inAddress,
                                                    UInt32 inQualifierDataSize,
                                                    const void *inQualifierData,
                                                    UInt32 *ioDataSize,
                                                    void *outData)
{
    return noErr;
}


@implementation CTSAudioHardwareServiceMock

- (OSStatus)audioObjectAddPropertyListener:(AudioObjectID)inObjectID
                                 inAddress:(const AudioObjectPropertyAddress *)inAddress
                                inListener:(AudioObjectPropertyListenerProc)inListener
                              inClientData:(void *)inClientData
{
    return noErr;
}

- (OSStatus)audioHardwareServiceAddPropertyListener:(AudioObjectID)inObjectID
                                          inAddress:(const AudioObjectPropertyAddress *)inAddress
                                         inListener:(AudioObjectPropertyListenerProc)inListener
                                       inClientData:(void *)inClientData
{
    return noErr;
}

- (OSStatus)audioHardwareServiceRemovePropertyListener:(AudioObjectID)inObjectID
                                             inAddress:(const AudioObjectPropertyAddress *)inAddress
                                            inListener:(AudioObjectPropertyListenerProc)inListener
                                          inClientData:(void *)inClientData
{
    return noErr;
}

- (OSStatus)audioHardwareServiceGetPropertyData:(AudioObjectID)inObjectID
                                      inAddress:(const AudioObjectPropertyAddress *)inAddress
                            inQualifierDataSize:(UInt32)inQualifierDataSize
                                inQualifierData:(const void *)inQualifierData
                                     ioDataSize:(UInt32 *)ioDataSize
                                        outData:(void *)outData
{
    return noErr;
}

@end
