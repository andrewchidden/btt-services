#import <XCTest/XCTest.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

#import "CTSWeakify.h"

#import "NSURL+CTSBetterTouchToolWebServerEndpoint.h"
#import "NSString+CTSSerializedVolumeStatus.h"

#import "CTSAudioToolboxVolumeServiceTestStub.h"
#import "CTSBetterTouchToolWebServerConfiguration.h"
#import "CTSVolumeService.h"

@class CTSVolumeServiceTests;
static CTSVolumeServiceTests *gVolumeServiceTestRunner = nil;
static CTSAudioHardwareServiceMock *gAudioToolboxServiceMock = nil;

OSStatus AudioObjectAddPropertyListener(AudioObjectID inObjectID,
                                               const AudioObjectPropertyAddress *inAddress,
                                               AudioObjectPropertyListenerProc inListener,
                                               void *inClientData)
{
    return [gAudioToolboxServiceMock audioObjectAddPropertyListener:inObjectID
                                                          inAddress:inAddress
                                                         inListener:inListener
                                                       inClientData:inClientData];
}

OSStatus AudioHardwareServiceAddPropertyListener(AudioObjectID inObjectID,
                                                        const AudioObjectPropertyAddress *inAddress,
                                                        AudioObjectPropertyListenerProc inListener,
                                                        void *inClientData)
{
    return [gAudioToolboxServiceMock audioHardwareServiceAddPropertyListener:inObjectID
                                                                   inAddress:inAddress
                                                                  inListener:inListener
                                                                inClientData:inClientData];
}

OSStatus AudioHardwareServiceRemovePropertyListener(AudioObjectID inObjectID,
                                                           const AudioObjectPropertyAddress *inAddress,
                                                           AudioObjectPropertyListenerProc inListener,
                                                           void *inClientData)
{
    return [gAudioToolboxServiceMock audioHardwareServiceRemovePropertyListener:inObjectID
                                                                      inAddress:inAddress
                                                                     inListener:inListener
                                                                   inClientData:inClientData];
}

OSStatus AudioHardwareServiceGetPropertyData(AudioObjectID inObjectID,
                                                    const AudioObjectPropertyAddress *inAddress,
                                                    UInt32 inQualifierDataSize,
                                                    const void *inQualifierData,
                                                    UInt32 *ioDataSize,
                                                    void *outData)
{
    return [gAudioToolboxServiceMock audioHardwareServiceGetPropertyData:inObjectID
                                                               inAddress:inAddress
                                                     inQualifierDataSize:inQualifierDataSize
                                                         inQualifierData:inQualifierData
                                                              ioDataSize:ioDataSize
                                                                 outData:outData];
}

OSStatus defaultListenerProc(AudioObjectID inObjectID,
                             UInt32 inNumberAddresses,
                             const AudioObjectPropertyAddress *inAddresses,
                             void *inClientData)
{
    return noErr;
}

NS_ASSUME_NONNULL_BEGIN

static NSString * const kTestStatusFilePath = @"/tmp/volume-service-test-status";

@interface CTSVolumeServiceTests : XCTestCase

@property (nonatomic, strong, readwrite) CTSVolumeService *service;
@property (nonatomic, strong, readwrite) NSURLSession *URLSessionMock;
@property (nonatomic, strong, readwrite) NSURLSessionTask *URLSessionTaskMock;
@property (nonatomic, strong, readwrite) CTSBetterTouchToolWebServerConfiguration *webServerConfigurationMock;
@property (nonatomic, assign, readwrite) AudioObjectPropertyListenerProc outputDeviceListenerProc;
@property (nonatomic, assign, readwrite) AudioObjectPropertyListenerProc outputVolumeListenerProc;
@property (nonatomic, assign, readwrite) AudioObjectPropertyListenerProc outputMuteListenerProc;

@property (nonatomic, assign, readwrite) AudioDeviceID currentOutputDeviceID;
@property (nonatomic, assign, readwrite) BOOL currentMuteState;
@property (nonatomic, assign, readwrite) Float32 currentOutputVolume;

// OCMockito has major problems with the bridging, so we need to run verifications in the mocks...
@property (nonatomic, assign, readwrite) BOOL didRequestMuteState;
@property (nonatomic, assign, readwrite) BOOL didRequestOutputVolume;
@property (nonatomic, assign, readwrite) BOOL didUnregisterMuteListener;
@property (nonatomic, assign, readwrite) BOOL didUnregisterOutputVolumeListener;

@end

@implementation CTSVolumeServiceTests

- (void)setUp
{
    [super setUp];

    gVolumeServiceTestRunner = self;
    gAudioToolboxServiceMock = mock([CTSAudioHardwareServiceMock class]);

    self.outputDeviceListenerProc = defaultListenerProc;
    self.outputVolumeListenerProc = defaultListenerProc;
    self.outputMuteListenerProc = defaultListenerProc;

    self.URLSessionMock = mock([NSURLSession class]);
    self.URLSessionTaskMock = mock([NSURLSessionTask class]);
    [given([self.URLSessionMock dataTaskWithRequest:anything()]) willReturn:self.URLSessionTaskMock];

    self.webServerConfigurationMock = mock([CTSBetterTouchToolWebServerConfiguration class]);
    [given(self.webServerConfigurationMock.URL) willReturn:[NSURL URLWithString:@"http://127.0.0.1:12345"]];
    [given(self.webServerConfigurationMock.sharedSecret) willReturn:@"a-very-secret-key"];

    [self captureOutputDeviceListener];
    [self captureVolumeListeners];
    [self captureRemoveVolumeListeners];
    [self mockVolumeDeviceProperties];

    self.currentOutputDeviceID = 99;
    self.currentOutputVolume = 0.1;
    self.currentMuteState = NO;
    
    self.service = [[CTSVolumeService alloc] initWithStatusFilePath:kTestStatusFilePath
                                                         URLSession:self.URLSessionMock
                                                         widgetUUID:@"a-widget-uuid"
                                             webServerConfiguration:self.webServerConfigurationMock
                                                   volumeThresholds:@[@50, @0]];
}

- (void)testServiceSetUp
{
    // Given no requests have been made
    assertThatBool(self.didRequestOutputVolume, isFalse());
    assertThatBool(self.didRequestMuteState, isFalse());
    //   And the service is not running
    assertThatBool([self.service isRunning], isFalse());

    // When the service is started
    [self.service start];

    // Then the service is now running
    assertThatBool([self.service isRunning], isTrue());
    //   And should begin observing output device changes
    assertThatBool(self.outputDeviceListenerProc != defaultListenerProc, isTrue());
    //   And observing output volume changes
    assertThatBool(self.outputVolumeListenerProc != defaultListenerProc, isTrue());
    //   And the current volume and mute state is retrieved
    assertThatBool(self.didRequestOutputVolume, isTrue());
    assertThatBool(self.didRequestMuteState, isTrue());
    //   And save the current volume to the status file
    [self verifyServiceSavesVolumeToStatusFile:[self currentVolumeStatusString]];
    //   And push the update to the widget.
    [self verifyServicePushesUpdateRequestToBTT];
}

- (void)testServiceHandlesOutputDeviceIDChange
{
    // Given no requests have been made
    assertThatBool(self.didRequestOutputVolume, isFalse());
    assertThatBool(self.didRequestMuteState, isFalse());
    //   And no listeners were unregistered yet
    assertThatBool(self.didUnregisterOutputVolumeListener, isFalse());
    assertThatBool(self.didUnregisterMuteListener, isFalse());
    //   And the service is started
    [self.service start];
    //   And saved the current volume to the status file
    NSString * const previousStatus = [self currentVolumeStatusString];
    [self verifyServiceSavesVolumeToStatusFile:previousStatus];
    //   And pushed the update to the widget
    [self verifyServicePushesUpdateRequestToBTT];

    // When the device ID changes
    self.currentOutputDeviceID = 33;
    //   And the device has a different output volume (that also crosses a threshold)
    self.currentOutputVolume = 0.99;
    AudioObjectPropertyAddress propAddr = {
        .mScope = kAudioObjectPropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioHardwarePropertyDefaultOutputDevice,
    };
    self.outputDeviceListenerProc(self.currentOutputDeviceID, 1, &propAddr, (__bridge void *)self.service);

    // Then it should unregister and re-register the listeners
    assertThatBool(self.didUnregisterOutputVolumeListener, isTrue());
    assertThatBool(self.didUnregisterMuteListener, isTrue());
    assertThatBool(self.outputDeviceListenerProc != defaultListenerProc, isTrue());
    assertThatBool(self.outputVolumeListenerProc != defaultListenerProc, isTrue());
    //   And fetch the latest device properties
    assertThatBool(self.didRequestOutputVolume, isTrue());
    assertThatBool(self.didRequestMuteState, isTrue());
    self.didRequestOutputVolume = NO;
    self.didRequestMuteState = NO;
    //   And should save the current volume to the status file
    [self verifyServiceSavesVolumeToStatusFile:[self currentVolumeStatusString]];
    //   And should push the update to the widget.
    [self verifyServicePushesUpdateRequestToBTT];
}

- (void)testServiceIgnoresSubThresholdVolumeChange
{
    // Given no requests have been made
    assertThatBool(self.didRequestOutputVolume, isFalse());
    assertThatBool(self.didRequestMuteState, isFalse());
    //   And the service is started
    [self.service start];
    //   And saved the current volume to the status file
    NSString * const previousStatus = [self currentVolumeStatusString];
    [self verifyServiceSavesVolumeToStatusFile:previousStatus];
    //   And pushed the update to the widget
    [self verifyServicePushesUpdateRequestToBTT];

    // When the output volume changes but doesn't cross a threshold
    [NSThread sleepForTimeInterval:0.05]; // after a short period (see debouncing)
    self.currentOutputVolume = 0.15;
    AudioObjectPropertyAddress propAddr = {
        .mScope = kAudioObjectPropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
    };
    self.outputVolumeListenerProc(self.currentOutputDeviceID, 1, &propAddr, (__bridge void *)self.service);

    // Then the service should fetch the latest device properties
    assertThatBool(self.didRequestOutputVolume, isTrue());
    assertThatBool(self.didRequestMuteState, isTrue());
    self.didRequestOutputVolume = NO;
    self.didRequestMuteState = NO;
    //   And should _not_ save the current volume to the status file
    [self verifyServiceSavesVolumeToStatusFile:previousStatus];
    //   And should _not_ push the update to the widget.
    [(NSURLSessionTask *)verifyCount(self.URLSessionTaskMock, never()) resume];
}

- (void)testServiceHandlesSuperThresholdVolumeChange
{
    // Given no requests have been made
    assertThatBool(self.didRequestOutputVolume, isFalse());
    assertThatBool(self.didRequestMuteState, isFalse());
    //   And the service is started
    [self.service start];
    //   And saved the current volume to the status file
    [self verifyServiceSavesVolumeToStatusFile:[self currentVolumeStatusString]];
    //   And pushed the update to the widget
    [self verifyServicePushesUpdateRequestToBTT];

    // When the output volume changes and _does_ cross a threshold
    self.currentOutputVolume = 0.99;
    AudioObjectPropertyAddress propAddr = {
        .mScope = kAudioObjectPropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
    };
    self.outputVolumeListenerProc(self.currentOutputDeviceID, 1, &propAddr, (__bridge void *)self.service);

    // Then the service should fetch the latest device properties
    assertThatBool(self.didRequestOutputVolume, isTrue());
    assertThatBool(self.didRequestMuteState, isTrue());
    self.didRequestOutputVolume = NO;
    self.didRequestMuteState = NO;
    //   And should save the current volume to the status file
    [self verifyServiceSavesVolumeToStatusFile:[self currentVolumeStatusString]];
    //   And should push the update to the widget.
    [self verifyServicePushesUpdateRequestToBTT];
}

- (void)testServiceHandlesAllChangesWithNoThresholdsConfigured
{
    // Given a service with no volume thresholds
    self.service = [[CTSVolumeService alloc] initWithStatusFilePath:kTestStatusFilePath
                                                         URLSession:self.URLSessionMock
                                                         widgetUUID:@"a-widget-uuid"
                                             webServerConfiguration:self.webServerConfigurationMock
                                                   volumeThresholds:nil];
    //   And no requests have been made
    assertThatBool(self.didRequestOutputVolume, isFalse());
    assertThatBool(self.didRequestMuteState, isFalse());
    //   And the service is started
    [self.service start];
    //   And saved the current volume to the status file
    [self verifyServiceSavesVolumeToStatusFile:[self currentVolumeStatusString]];
    //   And pushed the update to the widget
    [self verifyServicePushesUpdateRequestToBTT];

    // When the service receives an output volume change (but no change actually ocurred) after some time
    [NSThread sleepForTimeInterval:0.55];
    AudioObjectPropertyAddress propAddr = {
        .mScope = kAudioObjectPropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
    };
    self.outputVolumeListenerProc(self.currentOutputDeviceID, 1, &propAddr, (__bridge void *)self.service);

    // Then the service should still fetch the latest device properties
    assertThatBool(self.didRequestOutputVolume, isTrue());
    assertThatBool(self.didRequestMuteState, isTrue());
    self.didRequestOutputVolume = NO;
    self.didRequestMuteState = NO;
    //   And should save the current volume to the status file
    [self verifyServiceSavesVolumeToStatusFile:[self currentVolumeStatusString]];
    //   And should push the update to the widget.
    [self verifyServicePushesUpdateRequestToBTT];
}

- (void)testServiceDebouncesVolumeChangeEventsWithNoThresholdsConfigured
{
    // Given the service is configured with no volume thresholds
    self.service = [[CTSVolumeService alloc] initWithStatusFilePath:kTestStatusFilePath
                                                         URLSession:self.URLSessionMock
                                                         widgetUUID:@"a-widget-uuid"
                                             webServerConfiguration:self.webServerConfigurationMock
                                                   volumeThresholds:nil];
    //   And no requests have been made
    assertThatBool(self.didRequestOutputVolume, isFalse());
    assertThatBool(self.didRequestMuteState, isFalse());
    //   And the service is started
    [self.service start];
    //   And saved the current volume to the status file
    NSString * const previousStatus = [self currentVolumeStatusString];
    [self verifyServiceSavesVolumeToStatusFile:previousStatus];
    //   And pushed the update to the widget
    [self verifyServicePushesUpdateRequestToBTT];

    // When the output volume changes and _does_ cross a threshold but happens right after another update
    self.currentOutputVolume = 0.99;
    AudioObjectPropertyAddress propAddr = {
        .mScope = kAudioObjectPropertyScopeOutput,
        .mElement = kAudioObjectPropertyElementMaster,
        .mSelector = kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
    };
    self.outputVolumeListenerProc(self.currentOutputDeviceID, 1, &propAddr, (__bridge void *)self.service);

    // Then the service should fetch the latest device properties
    assertThatBool(self.didRequestOutputVolume, isTrue());
    assertThatBool(self.didRequestMuteState, isTrue());
    self.didRequestOutputVolume = NO;
    self.didRequestMuteState = NO;
    //   And should _not_ save the current volume to the status file
    [self verifyServiceSavesVolumeToStatusFile:previousStatus];
    //   And should _not_ push the update to the widget.
    [(NSURLSessionTask *)verifyCount(self.URLSessionTaskMock, never()) resume];
}

- (void)testServiceHandlesNoPushConfigurations
{
    // Given a service with created with a nil widget UUID
    CTSVolumeService * const noWidgetUUIDService =
        [[CTSVolumeService alloc] initWithStatusFilePath:kTestStatusFilePath
                                              URLSession:self.URLSessionMock
                                              widgetUUID:nil
                                  webServerConfiguration:self.webServerConfigurationMock
                                        volumeThresholds:@[@50, @0]];
    // When the service is started
    [noWidgetUUIDService start];
    // Then it should not attempt to push an update to BTT.
    [(NSURLSessionTask *)verifyCount(self.URLSessionTaskMock, never()) resume];
    
    // Given a service with created with a nil web server configuration
    CTSVolumeService * const noWebServerConfigurationService =
        [[CTSVolumeService alloc] initWithStatusFilePath:kTestStatusFilePath
                                              URLSession:self.URLSessionMock
                                              widgetUUID:@"a-widget-uuid"
                                  webServerConfiguration:nil
                                        volumeThresholds:@[@50, @0]];
    // When the service is started
    [noWebServerConfigurationService start];
    // Then it should not attempt to push an update to BTT.
    [(NSURLSessionTask *)verifyCount(self.URLSessionTaskMock, never()) resume];
}


#pragma mark - Verification helpers

- (void)verifyServiceSavesVolumeToStatusFile:(NSString *)expectedStatus
{
    NSError *error = nil;
    NSString * const statusMessage = [NSString stringWithContentsOfFile:kTestStatusFilePath
                                                               encoding:NSUTF8StringEncoding
                                                                  error:&error];
    assertThat(error, nilValue());
    assertThat(statusMessage, equalTo(expectedStatus));
}

- (void)verifyServicePushesUpdateRequestToBTT
{
    // A request is created using the URL session with the expected URL
    HCArgumentCaptor * const requestCaptor = [[HCArgumentCaptor alloc] init];
    [verify(self.URLSessionMock) dataTaskWithRequest:(id)requestCaptor];
    NSURLRequest * const request = (NSURLRequest *)requestCaptor.value;
    assertThat(request.URL, equalTo([NSURL cts_URLWithWebServerConfiguration:self.webServerConfigurationMock
                                                                endpoint:@"refresh_widget"
                                                         queryParameters:@[@"uuid=a-widget-uuid"]]));

    //   And the service starts the task.
    [(NSURLSessionTask *)verify(self.URLSessionTaskMock) resume];
}


#pragma mark - Mock helpers

- (void)mockVolumeDeviceProperties
{
    weakify(self);
    [[[[given([gAudioToolboxServiceMock audioHardwareServiceGetPropertyData:0
                                                                  inAddress:(__bridge void *)(anything())
                                                        inQualifierDataSize:0
                                                            inQualifierData:NULL
                                                                 ioDataSize:(__bridge void *)(anything())
                                                                    outData:(__bridge void *)(anything())])
        withMatcher:anything() forArgument:0]
       withMatcher:anything() forArgument:4]
      withMatcher:anything() forArgument:5]
     willDo:^id _Nonnull(NSInvocation * _Nonnull invocation) {
         strongify(self);

         // DRAGON: mkt_arguments returns incorrect things...
         AudioDeviceID deviceID;
         [invocation getArgument:&deviceID atIndex:2];
         UInt32 *size;
         [invocation getArgument:&size atIndex:6];
         AudioObjectPropertyAddress *propertyAddress;
         [invocation getArgument:&propertyAddress atIndex:3];

         if (deviceID == kAudioObjectSystemObject) {
             // DRAGON: mkt_arguments returns incorrect things...
             UInt32 *outputDeviceIDSize;
             [invocation getArgument:&outputDeviceIDSize atIndex:6];
             assertThatUnsignedInt(*outputDeviceIDSize, equalToUnsignedInt(sizeof(AudioDeviceID)));
             AudioDeviceID *deviceID;
             [invocation getArgument:&deviceID atIndex:7];
             *deviceID = self.currentOutputDeviceID;
         } else {
             assertThatUnsignedInt(deviceID, equalToUnsignedInt(self.currentOutputDeviceID));

             if (propertyAddress->mSelector == kAudioDevicePropertyMute) {
                 assertThatUnsignedInt(*size, equalToUnsignedInt(1));
                 BOOL *isMuted;
                 [invocation getArgument:&isMuted atIndex:7];
                 *isMuted = self.currentMuteState;
                 self.didRequestMuteState = YES;
             } else if (propertyAddress->mSelector == kAudioHardwareServiceDeviceProperty_VirtualMasterVolume) {
                 assertThatUnsignedInt(*size, equalToUnsignedInt(4));
                 Float32 *volume;
                 [invocation getArgument:&volume atIndex:7];
                 *volume = self.currentOutputVolume;
                 self.didRequestOutputVolume = YES;
             }
         }
         
         return @(noErr);
     }];
}


#pragma mark - Listener capturing

- (void)captureOutputDeviceListener
{
    weakify(self);
    [[[given([gAudioToolboxServiceMock audioObjectAddPropertyListener:kAudioObjectSystemObject
                                                            inAddress:(__bridge const AudioObjectPropertyAddress *)(anything())
                                                           inListener:0
                                                         inClientData:NULL])
       withMatcher:anything() forArgument:2]
      withMatcher:anything() forArgument:3]
     willDo:^id _Nonnull(NSInvocation * _Nonnull invocation) {
         strongify(self);

         // DRAGON: mkt_arguments returns incorrect things...
         AudioObjectPropertyAddress *propertyAddress;
         [invocation getArgument:&propertyAddress atIndex:3];
         AudioObjectPropertyListenerProc proc;
         [invocation getArgument:&proc atIndex:4];

         assertThatBool(propertyAddress->mScope == kAudioObjectPropertyScopeGlobal, isTrue());
         assertThatBool(propertyAddress->mElement == kAudioObjectPropertyElementMaster, isTrue());
         assertThatBool(propertyAddress->mSelector == kAudioHardwarePropertyDefaultOutputDevice, isTrue());

         self.outputDeviceListenerProc = proc;
         return @(noErr);
     }];
}

- (void)captureVolumeListeners
{
    weakify(self);
    [[[[given([gAudioToolboxServiceMock audioHardwareServiceAddPropertyListener:0
                                                                      inAddress:(__bridge const AudioObjectPropertyAddress *)(anything())
                                                                     inListener:0
                                                                   inClientData:NULL])
        withMatcher:anything() forArgument:0]
       withMatcher:anything() forArgument:2]
      withMatcher:anything() forArgument:3]
     willDo:^id _Nonnull(NSInvocation * _Nonnull invocation) {
         strongify(self);

         // DRAGON: mkt_arguments returns incorrect things...
         AudioObjectPropertyAddress *propertyAddress;
         [invocation getArgument:&propertyAddress atIndex:3];
         AudioObjectPropertyListenerProc proc;
         [invocation getArgument:&proc atIndex:4];

         assertThatBool(propertyAddress->mScope == kAudioDevicePropertyScopeOutput, isTrue());
         assertThatBool(propertyAddress->mElement == kAudioObjectPropertyElementMaster, isTrue());

         if (propertyAddress->mSelector == kAudioHardwareServiceDeviceProperty_VirtualMasterVolume) {
             self.outputVolumeListenerProc = proc;
         } else if (propertyAddress->mSelector == kAudioDevicePropertyMute) {
             self.outputMuteListenerProc = proc;
         }

         return @(noErr);
     }];
}

- (void)captureRemoveVolumeListeners
{
    weakify(self);
    [[[[given([gAudioToolboxServiceMock audioHardwareServiceRemovePropertyListener:0
                                                                         inAddress:(__bridge const AudioObjectPropertyAddress *)(anything())
                                                                        inListener:0
                                                                      inClientData:NULL])
        withMatcher:anything() forArgument:0]
       withMatcher:anything() forArgument:2]
      withMatcher:anything() forArgument:3]
     willDo:^id _Nonnull(NSInvocation * _Nonnull invocation) {
         strongify(self);

         // DRAGON: mkt_arguments returns incorrect things...
         AudioDeviceID deviceID;
         [invocation getArgument:&deviceID atIndex:2];
         AudioObjectPropertyAddress *propertyAddress;
         [invocation getArgument:&propertyAddress atIndex:3];
         AudioObjectPropertyListenerProc proc;
         [invocation getArgument:&proc atIndex:4];

         assertThatUnsignedInt(deviceID, isNot(equalToUnsignedInt(self.currentOutputDeviceID)));
         assertThatBool(propertyAddress->mScope == kAudioDevicePropertyScopeOutput, isTrue());
         assertThatBool(propertyAddress->mElement == kAudioObjectPropertyElementMaster, isTrue());

         if (propertyAddress->mSelector == kAudioHardwareServiceDeviceProperty_VirtualMasterVolume) {
             self.outputVolumeListenerProc = defaultListenerProc;
             self.didUnregisterOutputVolumeListener = YES;
         } else if (propertyAddress->mSelector == kAudioDevicePropertyMute) {
             self.outputMuteListenerProc = defaultListenerProc;
             self.didUnregisterMuteListener = YES;
         }

         return @(noErr);
     }];
}


#pragma mark - Utils

- (NSString *)currentVolumeStatusString
{
    int const roundedVolume = (int)round(self.currentOutputVolume*100.0);
    return [NSString cts_stringStatusWithVolume:roundedVolume muteState:self.currentMuteState];
}

@end

NS_ASSUME_NONNULL_END
