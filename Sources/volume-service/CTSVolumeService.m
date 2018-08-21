#import "CTSVolumeService.h"

#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>

#import "NSURL+CTSBetterTouchToolWebServerEndpoint.h"
#import "NSString+CTSSerializedVolumeStatus.h"

#import "CTSBetterTouchToolWebServerConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * const kBetterTouchToolRefreshWidgetEndpoint = @"refresh_widget";
#if TEST
static NSTimeInterval const kUpdateDebounceTimeInterval = 0.5; // Test is flaky with low debounce interval.
#else
static NSTimeInterval const kUpdateDebounceTimeInterval = 0.02;
#endif

@interface CTSVolumeService ()

@property (nonatomic, strong, readonly) NSString *statusFilePath;
@property (nonatomic, strong, readonly) NSURLSession *URLSession;
@property (nonatomic, strong, readonly, nullable) NSString *widgetUUID;
@property (nonatomic, strong, readonly, nullable) CTSBetterTouchToolWebServerConfiguration *webServerConfiguration;
@property (nonatomic, strong, readonly, nullable) NSArray<NSNumber *> *volumeThresholds;

@property (nonatomic, assign, readwrite) AudioDeviceID outputDeviceID;
@property (nonatomic, assign, readwrite) BOOL lastMuteState;
@property (nonatomic, assign, readwrite) int lastOutputVolume;
@property (nonatomic, assign, readwrite) CFAbsoluteTime lastUpdateTime;

@end

@implementation CTSVolumeService

@synthesize running = _running;

- (instancetype)initWithStatusFilePath:(NSString * const)statusFilePath
                            URLSession:(NSURLSession * const)URLSession
                            widgetUUID:(nullable NSString * const)widgetUUID
                webServerConfiguration:(nullable CTSBetterTouchToolWebServerConfiguration * const)webServerConfiguration
                      volumeThresholds:(nullable NSArray<NSNumber *> * const)volumeThresholds
{
    self = [super init];

    if (self) {
        _statusFilePath = statusFilePath;
        _URLSession = URLSession;
        _widgetUUID = widgetUUID;
        _webServerConfiguration = webServerConfiguration;
        _volumeThresholds = (volumeThresholds.count > 0 ? volumeThresholds : nil);
    }

    return self;
}

- (void)start
{
    _running = YES;
    
    [self registerOutputDeviceListener];
    self.outputDeviceID = [self defaultOutputDeviceID];
    self.lastMuteState = [self isMuted:self.outputDeviceID];
    self.lastOutputVolume = [self outputVolume:self.outputDeviceID];
    [self registerVolumeListener:self.outputDeviceID];

    // Immediately update status file with latest volume information.
    [self saveVolumeStatusToFile:self.lastMuteState outputVolume:self.lastOutputVolume];
}


#pragma mark - Audio service accessors

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (AudioDeviceID)defaultOutputDeviceID
{
    AudioObjectPropertyAddress propertyAddress = {
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioHardwarePropertyDefaultOutputDevice,
    };
    AudioDeviceID outputDeviceID = kAudioObjectUnknown;
    UInt32 outputDeviceIDSize = sizeof(outputDeviceID);
    AudioHardwareServiceGetPropertyData(kAudioObjectSystemObject,
                                        &propertyAddress,
                                        0,
                                        NULL,
                                        &outputDeviceIDSize,
                                        &outputDeviceID);
    return outputDeviceID;
}

- (BOOL)isMuted:(AudioDeviceID const)outputDeviceID
{
    AudioObjectPropertyAddress propertyAddress = {
        .mScope = kAudioObjectPropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioDevicePropertyMute,
    };
    BOOL isMuted;
    UInt32 isMutedSize = sizeof(isMuted);

    AudioHardwareServiceGetPropertyData(outputDeviceID,
                                        &propertyAddress,
                                        0,
                                        NULL,
                                        &isMutedSize,
                                        &isMuted);
    return isMuted;
}

- (int)outputVolume:(AudioDeviceID const)outputDeviceID
{
    AudioObjectPropertyAddress propertyAddress = {
        .mScope = kAudioObjectPropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
    };
    Float32 volume;
    UInt32 volumeSize = sizeof(volume);

    AudioHardwareServiceGetPropertyData(outputDeviceID,
                                        &propertyAddress,
                                        0,
                                        NULL,
                                        &volumeSize,
                                        &volume);
    return (int)round(volume*100.0);
}
#pragma clang diagnostic pop


#pragma mark - Output volume event handling

OSStatus onVolumeChange(AudioObjectID inObjectID,
                        UInt32 inNumberAddresses,
                        const AudioObjectPropertyAddress *inAddresses,
                        void *inClientData)
{
    return [(__bridge CTSVolumeService *)inClientData onVolumeChange:inObjectID
                                                   inNumberAddresses:inNumberAddresses
                                                         inAddresses:inAddresses
                                                        inClientData:inClientData];
}

- (OSStatus)onVolumeChange:(AudioObjectID)inObjectID
         inNumberAddresses:(UInt32)inNumberAddresses
               inAddresses:(const AudioObjectPropertyAddress *)inAddresses
              inClientData:(void *)inClientData
{
    [self updateVolumeStatus];
    return noErr;
}


#pragma mark - Output device event handling

OSStatus onDefaultOutputDeviceChanged(AudioObjectID inObjectID,
                                      UInt32 inNumberAddresses,
                                      const AudioObjectPropertyAddress *inAddresses,
                                      void *inClientData)
{
    return [(__bridge CTSVolumeService *)inClientData onDefaultOutputDeviceChanged:inObjectID
                                                                 inNumberAddresses:inNumberAddresses
                                                                       inAddresses:inAddresses
                                                                      inClientData:inClientData];
}

- (OSStatus)onDefaultOutputDeviceChanged:(AudioObjectID const)inObjectID
                       inNumberAddresses:(UInt32)inNumberAddresses
                             inAddresses:(const AudioObjectPropertyAddress *)inAddresses
                            inClientData:(void *)inClientData
{
    [self unregisterVolumeListener:self.outputDeviceID];
    self.outputDeviceID = [self defaultOutputDeviceID];
    [self registerVolumeListener:self.outputDeviceID];
    // Update volume status, which may have changed when switching devices.
    [self updateVolumeStatus];
    return noErr;
}


#pragma mark - Event observing

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (BOOL)registerVolumeListener:(AudioDeviceID const)outputDeviceID
{
    // Output volume listener
    AudioObjectPropertyAddress ouputVolumePropertyAddress = {
        .mScope = kAudioDevicePropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
    };
    OSStatus outputRegistryStatus = AudioHardwareServiceAddPropertyListener(outputDeviceID,
                                                                            &ouputVolumePropertyAddress,
                                                                            onVolumeChange,
                                                                            (__bridge void *)self);

    // Mute change listener
    AudioObjectPropertyAddress mutePropertyAddress = {
        .mScope = kAudioObjectPropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioDevicePropertyMute,
    };
    OSStatus muteRegistryStatus = AudioHardwareServiceAddPropertyListener(outputDeviceID,
                                                                          &mutePropertyAddress,
                                                                          onVolumeChange,
                                                                          (__bridge void *)self);

    return outputRegistryStatus == noErr
        && muteRegistryStatus == noErr;
}

- (BOOL)unregisterVolumeListener:(AudioDeviceID const)outputDeviceID
{
    // Output volume listener
    AudioObjectPropertyAddress ouputVolumePropAddr = {
        .mScope = kAudioDevicePropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
    };
    OSStatus outputRegistryStatus = AudioHardwareServiceRemovePropertyListener(outputDeviceID,
                                                                               &ouputVolumePropAddr,
                                                                               onVolumeChange,
                                                                               (__bridge void *)self);

    // Mute change listener
    AudioObjectPropertyAddress mutePropAddr = {
        .mScope = kAudioObjectPropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioDevicePropertyMute,
    };
    OSStatus muteRegistryStatus = AudioHardwareServiceRemovePropertyListener(outputDeviceID,
                                                                             &mutePropAddr,
                                                                             onVolumeChange,
                                                                             (__bridge void *)self);

    return outputRegistryStatus == noErr
    && muteRegistryStatus == noErr;
}

- (BOOL)registerOutputDeviceListener
{
    // Device change listener
    AudioObjectPropertyAddress devicePropAddr = {
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioHardwarePropertyDefaultOutputDevice,
    };
    OSStatus deviceRegistryStatus = AudioObjectAddPropertyListener(kAudioObjectSystemObject,
                                                                   &devicePropAddr,
                                                                   onDefaultOutputDeviceChanged,
                                                                   (__bridge void *)self);
    return deviceRegistryStatus == noErr;
}
#pragma clang diagnostic pop


#pragma mark - Update and notify BTT

- (void)updateVolumeStatus
{
    int const newOutputVolume = [self outputVolume:self.outputDeviceID];
    BOOL const newMuteState = [self isMuted:self.outputDeviceID];

#if DEBUG
    NSLog(@"Got volume status change, volume: %d, mute state: %d", newOutputVolume, newMuteState);
#endif

    if (self.volumeThresholds) {
        if (newMuteState != self.lastMuteState ||
            [self didOutputVolumeCrossThreshold:self.lastOutputVolume newOutputVolume:newOutputVolume]) {
            [self saveVolumeStatusToFile:newMuteState outputVolume:newOutputVolume];
        }
    } else {
        [self saveVolumeStatusToFile:newMuteState outputVolume:newOutputVolume];
    }

    self.lastOutputVolume = newOutputVolume;
    self.lastMuteState = newMuteState;
}

- (void)saveVolumeStatusToFile:(BOOL const)muteState outputVolume:(int const)outputVolume
{
    CFAbsoluteTime const currentTime = CFAbsoluteTimeGetCurrent();
    if (!self.volumeThresholds && currentTime - self.lastUpdateTime < kUpdateDebounceTimeInterval) {
        return;
    }
    self.lastUpdateTime = currentTime;

    NSString *status = [NSString cts_stringStatusWithVolume:outputVolume muteState:muteState];
    NSError *error = nil;
    [status writeToFile:self.statusFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];

#if DEBUG
    NSLog(@"Saved volume to status file, status: %@, file path: %@, error: %@", status, self.statusFilePath, error);
#endif

    [self pushUpdateToWidget];
}


- (void)pushUpdateToWidget
{
    if (!self.webServerConfiguration || !self.widgetUUID) {
        return;
    }

    NSURL * const URL = [NSURL cts_URLWithWebServerConfiguration:self.webServerConfiguration
                                                    endpoint:kBetterTouchToolRefreshWidgetEndpoint
                                             queryParameters:@[[NSString stringWithFormat:@"uuid=%@",self.widgetUUID]]];
    NSURLRequest * const request = [NSURLRequest requestWithURL:URL
                                                    cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                timeoutInterval:1.0];
    NSURLSessionTask * const task = [self.URLSession dataTaskWithRequest:request];
    [task resume];

#if DEBUG
    NSLog(@"Pushed update to BTT web server at URL: %@", URL);
#endif
}


#pragma mark - Utils

- (NSUInteger)indexFromOutputVolume:(int const)outputVolume
{
    int index = 0;
    for (NSNumber * const threshold in self.volumeThresholds) {
        if (outputVolume > [threshold integerValue]) {
            break;
        }
        index += 1;
    }
    return index;
}

- (BOOL)didOutputVolumeCrossThreshold:(int const)oldOutputVolume newOutputVolume:(int const)newOutputVolume
{
    return ([self indexFromOutputVolume:oldOutputVolume] != [self indexFromOutputVolume:newOutputVolume]);
}

@end

NS_ASSUME_NONNULL_END
