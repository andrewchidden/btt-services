#import <XCTest/XCTest.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

#import <IOKit/hidsystem/ev_keymap.h>
#import "CTSWeakify.h"

#import "CTSAudioToolboxControlStripServiceTestStub.h"
#import "CTSCoreGraphicsEventControlStripServiceTestStub.h"
#import "CTSControlStripService.h"

@class CTSControlStripServiceTests;
static CTSControlStripServiceTests *gControlStripServiceTestRunner = nil;
static CTSAudioServicesMock *gAudioServicesMock = nil;
static CTSCoreGraphicsEventMock *gCoreGraphicsEventMock = nil;

OSStatus AudioServicesCreateSystemSoundID(CFURLRef inFileURL,
                                          SystemSoundID *outSystemSoundID)
{
    return [gAudioServicesMock audioServicesCreateSystemSoundID:inFileURL outSystemSoundID:outSystemSoundID];
}

void AudioServicesPlaySystemSound(SystemSoundID inSystemSoundID)
{
    [gAudioServicesMock audioServicesPlaySystemSound:inSystemSoundID];
}

void CGEventPost(CGEventTapLocation tap, CGEventRef __nullable event)
{
    [gCoreGraphicsEventMock cgEventPost:tap event:event];
}

NS_ASSUME_NONNULL_BEGIN

static NSEventModifierFlags const kSmallStepModifierFlags = (NSEventModifierFlagShift | NSEventModifierFlagOption);
static NSString * const kFeedbackSoundFilePath =
    @"/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff";
static SystemSoundID kFeedbackSoundID = 123;
static NSString * const kSystemPreferencePaneBasePath = @"/System/Library/PreferencePanes/";
static NSString * const kSoundPreferencePaneFileName = @"Sound.prefPane";
static NSString * const kDisplaysPreferencePaneFileName = @"Displays.prefPane";

@interface CTSControlStripServiceTests : XCTestCase

@property (nonatomic, strong, readwrite) NSWorkspace *workspaceMock;
@property (nonatomic, assign, readwrite) BOOL createdFeedbackSoundID;
@property (nonatomic, strong, readwrite) NSURL *retainedSoundSystemURL;

@end

@implementation CTSControlStripServiceTests

- (void)setUp
{
    [super setUp];

    gAudioServicesMock = mock([CTSAudioServicesMock class]);
    gCoreGraphicsEventMock = mock([CTSCoreGraphicsEventMock class]);

    weakify(self);
    [[[given([gAudioServicesMock audioServicesCreateSystemSoundID:0 outSystemSoundID:0])
       withMatcher:anything() forArgument:0]
      withMatcher:anything() forArgument:1]
     willDo:^id _Nonnull(NSInvocation * _Nonnull invocation) {
         strongify(self);
         NSURL * _Nullable URL = nil;
         [invocation getArgument:&URL atIndex:2];
         NSURL * const expectedURL = [NSURL fileURLWithPath:kFeedbackSoundFilePath isDirectory:NO];
         assertThat(URL, equalTo(expectedURL));
         if ([URL isEqualTo:expectedURL]) {
             self.createdFeedbackSoundID = YES;
         }
         self.retainedSoundSystemURL = URL; // HACK: CFURLRef being double-freed due to this block.

         SystemSoundID *soundID;
         [invocation getArgument:&soundID atIndex:3];
         *soundID = kFeedbackSoundID;

         return @(noErr);
     }];

    self.workspaceMock = mock([NSWorkspace class]);
}

- (void)testServiceHandlesVolumeUpControl
{
    XCTestExpectation * const expectation =
        [[XCTestExpectation alloc] initWithDescription:@"Events should be synthesized"];
    expectation.expectedFulfillmentCount = 2;
    [self captureKeyPressWithKeyCode:NX_KEYTYPE_SOUND_UP
                       shouldKeyDown:YES
                  shouldUseSmallStep:NO
                         expectation:expectation];

    // Given the service is created with the volume up control type and feedback sounds enabled
    CTSControlStripService * const service =
        [[CTSControlStripService alloc] initWithControlType:CTSControlStripVolumeUpControl
                                      volumeFeedbackEnabled:YES
                                              modifierFlags:0
                                                  workspace:self.workspaceMock];

    // When it is started
    [service start];

    // Then the service should synthesize and perform the expected key press events
    [self waitForExpectations:@[expectation] timeout:1.0];
    //   And no volume feedback sounds are played.
    [[[verifyCount(gAudioServicesMock, never())
       withMatcher:anything() forArgument:0]
      withMatcher:anything() forArgument:1]
     audioServicesCreateSystemSoundID:0 outSystemSoundID:0];
}

- (void)testServiceHandlesSmallStepBrightnessDownControl
{
    XCTestExpectation * const expectation =
        [[XCTestExpectation alloc] initWithDescription:@"Events should be synthesized"];
    expectation.expectedFulfillmentCount = 2;
    [self captureKeyPressWithKeyCode:NX_KEYTYPE_BRIGHTNESS_DOWN
                       shouldKeyDown:YES
                  shouldUseSmallStep:YES
                         expectation:expectation];

    // Given the service is created with the brightness down control type and small step modifiers
    CTSControlStripService * const service =
        [[CTSControlStripService alloc] initWithControlType:CTSControlStripBrightnessDownControl
                                      volumeFeedbackEnabled:YES
                                              modifierFlags:kSmallStepModifierFlags
                                                  workspace:self.workspaceMock];

    // When it is started
    [service start];

    // Then the service should synthesize and perform the expected small step key press events
    [self waitForExpectations:@[expectation] timeout:1.0];
    //   And no volume feedback sounds are played.
    [[[verifyCount(gAudioServicesMock, never())
       withMatcher:anything() forArgument:0]
      withMatcher:anything() forArgument:1]
     audioServicesCreateSystemSoundID:0 outSystemSoundID:0];
}

- (void)testServiceHandlesKeyboardIlluminationDownControl
{
    XCTestExpectation * const expectation =
        [[XCTestExpectation alloc] initWithDescription:@"Events should be synthesized"];
    expectation.expectedFulfillmentCount = 2;
    [self captureKeyPressWithKeyCode:NX_KEYTYPE_ILLUMINATION_DOWN
                       shouldKeyDown:YES
                  shouldUseSmallStep:NO
                         expectation:expectation];

    // Given the service is created with the brightnes down control type and shift modifier
    CTSControlStripService * const service =
        [[CTSControlStripService alloc] initWithControlType:CTSControlStripBrightnessDownControl
                                      volumeFeedbackEnabled:YES
                                              modifierFlags:NSEventModifierFlagShift
                                                  workspace:self.workspaceMock];

    // When it is started
    [service start];

    // Then the service should synthesize and perform the expected illumination key press events
    [self waitForExpectations:@[expectation] timeout:1.0];
    //   And no volume feedback sounds are played.
    [[[verifyCount(gAudioServicesMock, never())
       withMatcher:anything() forArgument:0]
      withMatcher:anything() forArgument:1]
     audioServicesCreateSystemSoundID:0 outSystemSoundID:0];
}

- (void)testServicePlaysVolumeFeedbackSounds
{
    XCTestExpectation * const expectation =
        [[XCTestExpectation alloc] initWithDescription:@"Feedback sound should be played"];
    [self capturePlaySystemSoundWithExpectation:expectation];

    // Given the service is created with the volume up control type, feedback sounds enabled, and shift modifier
    CTSControlStripService * const service =
        [[CTSControlStripService alloc] initWithControlType:CTSControlStripVolumeUpControl
                                      volumeFeedbackEnabled:YES
                                              modifierFlags:NSEventModifierFlagShift
                                                  workspace:self.workspaceMock];
    //   And no feedback sound ID was created yet
    assertThatBool(self.createdFeedbackSoundID, isFalse());

    // When it is started
    [service start];

    // Then the service should have played volume feedback sounds.
    assertThatBool(self.createdFeedbackSoundID, isTrue());
    // DRAGON: OCMockito doesn't get the correct sound ID value with direct verification...
    [self waitForExpectations:@[expectation] timeout:1.0];
}

- (void)testServiceOpensVolumePreferencePane
{
    // Given the service is created with the volume down control type and the option modifier
    CTSControlStripService * const service =
        [[CTSControlStripService alloc] initWithControlType:CTSControlStripVolumeDownControl
                                      volumeFeedbackEnabled:YES
                                              modifierFlags:NSEventModifierFlagOption
                                                  workspace:self.workspaceMock];

    // When it is started
    [service start];

    // Then the service should open the volume preference pane.
    NSString * const preferencePanePath =
        [kSystemPreferencePaneBasePath stringByAppendingPathComponent:kSoundPreferencePaneFileName];
    [verify(self.workspaceMock) openFile:preferencePanePath];
}

- (void)testServiceOpensDisplaysPreferencePane
{
    // Given the service is created with the volume down control type and the option modifier
    CTSControlStripService * const service =
    [[CTSControlStripService alloc] initWithControlType:CTSControlStripBrightnessDownControl
                                  volumeFeedbackEnabled:YES
                                          modifierFlags:NSEventModifierFlagOption
                                              workspace:self.workspaceMock];

    // When it is started
    [service start];

    // Then the service should open the volume preference pane.
    NSString * const preferencePanePath =
        [kSystemPreferencePaneBasePath stringByAppendingPathComponent:kDisplaysPreferencePaneFileName];
    [verify(self.workspaceMock) openFile:preferencePanePath];
}


#pragma mark - Utils

- (void)captureKeyPressWithKeyCode:(CGKeyCode const)keyCode
                     shouldKeyDown:(BOOL const)shouldKeyDown
                shouldUseSmallStep:(BOOL const)shouldUseSmallStep
                       expectation:(XCTestExpectation * const)expectation
{

    __block BOOL shouldKeyDownFlag = shouldKeyDown;
    [[givenVoid([gCoreGraphicsEventMock cgEventPost:kCGHIDEventTap event:0]) withMatcher:anything() forArgument:1]
     willDo:^id _Nonnull(NSInvocation * _Nonnull invocation) {
         // DRAGON: OCMockito fails to get event ref arguments through `mkt_arguments`.
         CGEventRef _Nullable keyDownRef = nil;
         [invocation getArgument:&keyDownRef atIndex:3];

         assertThat((__bridge id)keyDownRef, notNilValue());
         if (!keyDownRef) {
             return nil;
         }

         NSEvent * _Nullable const keyDownEvent = [NSEvent eventWithCGEvent:keyDownRef];
         assertThat(keyDownEvent, notNilValue());

         NSEventModifierFlags const modifier = (shouldKeyDownFlag ? NX_KEYDOWN : NX_KEYUP);
         NSEventModifierFlags const smallStepModifier = (shouldUseSmallStep ? kSmallStepModifierFlags : 0);

         assertThatUnsignedInteger(keyDownEvent.type, equalToUnsignedInteger(NSEventTypeSystemDefined));
         assertThatBool(CGPointEqualToPoint(keyDownEvent.locationInWindow, CGPointZero), isTrue());
         assertThatUnsignedInteger(keyDownEvent.modifierFlags, equalToUnsignedInteger(modifier | smallStepModifier));
         assertThatDouble(keyDownEvent.timestamp, equalToDouble(0));
         assertThatShort(keyDownEvent.subtype, equalToShort(8));
         assertThatInteger(keyDownEvent.data1, equalToInteger((keyCode << 16) | (modifier << 8)));
         assertThatInteger(keyDownEvent.data2, equalToInteger(-1));

         shouldKeyDownFlag = NO;
         [expectation fulfill];
         return nil;
    }];
}

- (void)capturePlaySystemSoundWithExpectation:(XCTestExpectation * const)expectation
{
    [[givenVoid([gAudioServicesMock audioServicesPlaySystemSound:0])
      withMatcher:anything() forArgument:0] willDo:^id _Nonnull(NSInvocation * _Nonnull invocation) {
        SystemSoundID soundID;
        [invocation getArgument:&soundID atIndex:2];
        assertThatInteger(soundID, equalToInteger(kFeedbackSoundID));

        [expectation fulfill];
        return nil;
    }];
}

@end

NS_ASSUME_NONNULL_END
