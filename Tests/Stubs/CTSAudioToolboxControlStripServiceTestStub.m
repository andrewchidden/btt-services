#import "CTSAudioToolboxControlStripServiceTestStub.h"

OSStatus AudioServicesCreateSystemSoundID(CFURLRef inFileURL,
                                                 SystemSoundID *outSystemSoundID)
{
    return noErr;
}

void AudioServicesPlaySystemSound(SystemSoundID inSystemSoundID)
{
}

@implementation CTSAudioServicesMock

- (OSStatus)audioServicesCreateSystemSoundID:(CFURLRef)inFileURL
                            outSystemSoundID:(SystemSoundID *)outSystemSoundID
{
    return noErr;
}

- (void)audioServicesPlaySystemSound:(SystemSoundID)inSystemSoundID
{
}

@end
