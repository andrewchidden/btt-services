#import <XCTest/XCTest.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

#import <EventKit/EventKit.h>

#import "CTSEventKitService.h"
#import "CTSBetterTouchToolWebServerConfiguration.h"
#import "NSString+CTSReadableEventStatus.h"
#import "NSURL+CTSBetterTouchToolWebServerEndpoint.h"
#import "CTSWeakify.h"

NS_ASSUME_NONNULL_BEGIN

static NSString * const kTestStatusFilePath = @"/tmp/eventkit-service-test-status";
static NSString * const kEmptyTestStatus = @"%empty-test-status%";

@interface CTSEventKitServiceTests : XCTestCase

@property (nonatomic, strong, readwrite) CTSEventKitService *service;
@property (nonatomic, strong, readwrite) EKEventStore *eventStoreMock;
@property (nonatomic, strong, readwrite) EKCalendar *calendarMock;
@property (nonatomic, strong, readwrite) EKEvent *nextEventMock;
@property (nonatomic, strong, readwrite) EKEvent *futureEventMock;
@property (nonatomic, strong, readwrite) NSPredicate *nextEventPredicateMock;
@property (nonatomic, strong, readwrite) NSNotificationCenter *notificationCenterMock;
@property (nonatomic, strong, readwrite) NSURLSession *URLSessionMock;
@property (nonatomic, strong, readwrite) NSURLSessionTask *URLSessionTaskMock;
@property (nonatomic, strong, readwrite) CTSBetterTouchToolWebServerConfiguration *webServerConfigurationMock;
@property (nonatomic, strong, readwrite) NSRunLoop *runLoopMock;

@end

@implementation CTSEventKitServiceTests

- (void)setUp
{
    [super setUp];

    self.eventStoreMock = mock([EKEventStore class]);

    self.calendarMock = mock([EKCalendar class]);
    [given(self.calendarMock.title) willReturn:@"Shared"];
    [[given([self.eventStoreMock calendarsForEntityType:0]) withMatcher:equalToUnsignedInteger(EKEntityTypeEvent)
                                                            forArgument:0]
        willReturn:@[self.calendarMock]];

    [self mockCalendarEventsWithNextEventTitle:@"Top Secret Meeting" futureEventTitle:@"A Long Meeting"];

    self.notificationCenterMock = mock([NSNotificationCenter class]);
    self.URLSessionMock = mock([NSURLSession class]);
    self.URLSessionTaskMock = mock([NSURLSessionTask class]);
    [given([self.URLSessionMock dataTaskWithRequest:anything()]) willReturn:self.URLSessionTaskMock];

    self.webServerConfigurationMock = mock([CTSBetterTouchToolWebServerConfiguration class]);
    [given(self.webServerConfigurationMock.URL) willReturn:[NSURL URLWithString:@"http://127.0.0.1:12345"]];
    [given(self.webServerConfigurationMock.sharedSecret) willReturn:@"a-very-secret-key"];

    self.runLoopMock = mock([NSRunLoop class]);

    [self resetStatusFile];
    
    self.service = [[CTSEventKitService alloc] initWithEventStore:self.eventStoreMock
                                               notificationCenter:self.notificationCenterMock
                                                       URLSession:self.URLSessionMock
                                                          runLoop:self.runLoopMock
                                                   eventLookahead:60*60*24
                                                   statusFilePath:kTestStatusFilePath
                                                  noEventsMessage:@"No events"
                                                    calendarNames:@[@"user@domain.com", @"Shared"]
                                                       widgetUUID:@"a-widget-uuid"
                                           webServerConfiguration:self.webServerConfigurationMock];
}

- (void)testServiceHandlesNoCalendarAccessPermissions
{
    weakify(self);
    [self verifyServiceStart:self.service withBlock:^(EKEventStoreRequestAccessCompletionHandler completionHandler) {
        strongify(self);
        // When the service receives an error and no access permissions
        completionHandler(NO, [NSError errorWithDomain:NSStringFromClass([self class]) code:-1 userInfo:nil]);
        // Then the service should no longer be running.
        assertThatBool([self.service isRunning], isFalse());
    }];
}

- (void)testServiceSetUp
{
    weakify(self);
    [self verifyServiceStart:self.service withBlock:^(EKEventStoreRequestAccessCompletionHandler completionHandler) {
        strongify(self);
        // When the service receives access permissions to the calendar
        completionHandler(YES, nil);
        // Then the service should still be running.
        assertThatBool([self.service isRunning], isTrue());
        //   And it should retrieve the latest calendars
        [verify(self.eventStoreMock) calendarsForEntityType:EKEntityTypeEvent];
        //   And it should fetch the next event and save it's readable status message to the file path
        [self verifyServiceSavesNextEventToStatusFile:@"Top Secret Meeting in 1 hr"];
        //   And it should push the update to the widget.
        [self verifyServicePushesUpdateRequestToBTT];
    }];
}

- (void)testServiceUpdateEventTimer
{
    weakify(self);
    [self verifyServiceStart:self.service withBlock:^(EKEventStoreRequestAccessCompletionHandler completionHandler) {
        strongify(self);
        // When the service receives access permissions to the calendar
        completionHandler(YES, nil);
        // Then the service should add an update event timer to the run loop.
        HCArgumentCaptor * const timerCaptor = [HCArgumentCaptor new];
        [verify(self.runLoopMock) addTimer:(id)timerCaptor forMode:NSRunLoopCommonModes];
        assertThat(timerCaptor.value, notNilValue());
        NSTimer * const timer = (NSTimer *)timerCaptor.value;
        assertThatDouble(timer.timeInterval, equalToDouble(15.0));
        assertThatBool(timer.isValid, isTrue());
        //   And push the current event status to the widget.
        [self verifyServicePushesUpdateRequestToBTT];

        // And Given the next event has now ended
        [self resetStatusFile];
        [given(self.nextEventMock.startDate) willReturn:[NSDate distantPast]];
        [given(self.nextEventMock.endDate) willReturn:[NSDate distantPast]];

        // When the timer is fired
        [timer fire];
        // Then the service should save the empty status message to the file path
        [self verifyServiceSavesNextEventToStatusFile:@"No events"];
        //   And it should push the update to the widget.
        [self verifyServicePushesUpdateRequestToBTT];
    }];
}

- (void)testServiceHandlesEventStoreChangeNotifications
{
    weakify(self);
    [self verifyServiceStart:self.service withBlock:^(EKEventStoreRequestAccessCompletionHandler completionHandler) {
        strongify(self);
        // When the service receives access permissions to the calendar
        completionHandler(YES, nil);
        // Then it should add an observer to notification center for event store changes
        HCArgumentCaptor * const selectorCaptor = [HCArgumentCaptor new];
        [[verify(self.notificationCenterMock) withMatcher:(id)selectorCaptor forArgument:1]
         addObserver:self.service
         selector:@selector(testServiceSetUp)
         name:EKEventStoreChangedNotification
         object:self.eventStoreMock];
        //   And push the current event status to the widget.
        [self verifyServicePushesUpdateRequestToBTT];

        // And Given the event information changes change
        [self resetStatusFile];
        [self mockCalendarEventsWithNextEventTitle:@"Foo Bar Event" futureEventTitle:@"A Long Meeting"];

        // When the service receives an event store notification.
        assertThat(selectorCaptor.value, notNilValue());
        if (selectorCaptor.value) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self.service performSelector:NSSelectorFromString(selectorCaptor.value)
                               withObject:mock([NSNotification class])];
#pragma clang diagnostic pop
            // Then it should update the status file after some time.
            [self verifyServiceSavesNextEventToStatusFile:@"Foo Bar Event in 1 hr"];
            //   And push the update to the widget.
            [self verifyServicePushesUpdateRequestToBTT];
        }
    }];
}

- (void)testServiceOnlyPushesUpdatesWithChanges
{
    weakify(self);
    [self verifyServiceStart:self.service withBlock:^(EKEventStoreRequestAccessCompletionHandler completionHandler) {
        strongify(self);
        // When the service receives access permissions to the calendar
        completionHandler(YES, nil);
        //   And it should fetch the next event and save it's readable status message to the file path
        [self verifyServiceSavesNextEventToStatusFile:@"Top Secret Meeting in 1 hr"];
        //   And it should push the update to the widget.
        [self verifyServicePushesUpdateRequestToBTT];

        // And Given the event information does not change
        [self resetStatusFile];
        // When the service is updated again (by timer)
        HCArgumentCaptor * const timerCaptor = [HCArgumentCaptor new];
        [verify(self.runLoopMock) addTimer:(id)timerCaptor forMode:NSRunLoopCommonModes];
        assertThat(timerCaptor.value, notNilValue());
        NSTimer * const timer = (NSTimer *)timerCaptor.value;
        [timer fire];
        // Then the service does not update the status file
        [self verifyServiceSavesNextEventToStatusFile:kEmptyTestStatus];
        //   And does not push to BTT.
        [(NSURLSessionTask *)verifyCount(self.URLSessionTaskMock, never()) resume];
    }];
}

- (void)testServiceHandlesNoPushConfigurations
{
    // Given a service with created with a nil widget UUID
    CTSEventKitService * const noWidgetUUIDService =
        [[CTSEventKitService alloc] initWithEventStore:self.eventStoreMock
                                    notificationCenter:self.notificationCenterMock
                                            URLSession:self.URLSessionMock
                                               runLoop:self.runLoopMock
                                        eventLookahead:60*60*24
                                        statusFilePath:kTestStatusFilePath
                                       noEventsMessage:@"No events"
                                         calendarNames:@[@"user@domain.com", @"Shared"]
                                            widgetUUID:nil
                                webServerConfiguration:self.webServerConfigurationMock];
    [self verfiyServiceStartDoesNotPushToBTT:noWidgetUUIDService];

    // Given a service with created with a nil web server configuration
    CTSEventKitService * const noWebServerConfigurationService =
        [[CTSEventKitService alloc] initWithEventStore:self.eventStoreMock
                                    notificationCenter:self.notificationCenterMock
                                            URLSession:self.URLSessionMock
                                               runLoop:self.runLoopMock
                                        eventLookahead:60*60*24
                                        statusFilePath:kTestStatusFilePath
                                       noEventsMessage:@"No events"
                                         calendarNames:@[@"user@domain.com", @"Shared"]
                                            widgetUUID:nil
                                webServerConfiguration:self.webServerConfigurationMock];
    [self verfiyServiceStartDoesNotPushToBTT:noWebServerConfigurationService];
}


#pragma mark - Verification helpers

- (void)verifyServiceStart:(CTSEventKitService * const)service
                 withBlock:(void (^_Nonnull)(EKEventStoreRequestAccessCompletionHandler completionHandler))block
{
    // Given the service is not yet running
    assertThatBool([service isRunning], isFalse());

    // When the service is started
    [service start];

    // Then it should now be running
    assertThatBool([service isRunning], isTrue());
    //   And it should request access permissions to the user's calendar.
    HCArgumentCaptor * const completionCaptor = [HCArgumentCaptor new];
    [verify(self.eventStoreMock) requestAccessToEntityType:EKEntityTypeEvent completion:(id)completionCaptor];
    assertThat(completionCaptor.value, notNilValue());
    if (completionCaptor.value) {
        EKEventStoreRequestAccessCompletionHandler const completionBlock =
            (EKEventStoreRequestAccessCompletionHandler)completionCaptor.value;
        block(completionBlock);
    }
}

- (void)verfiyServiceStartDoesNotPushToBTT:(CTSEventKitService * const)service
{
    weakify(self);
    [self verifyServiceStart:service withBlock:^(EKEventStoreRequestAccessCompletionHandler completionHandler) {
        strongify(self);
        // When the service receives access permissions to the calendar
        completionHandler(YES, nil);
        // Then service should _not_ attempt to push anything to BTT.
        [(NSURLSessionTask *)verifyCount(self.URLSessionTaskMock, never()) resume];
    }];
}

- (void)verifyServiceSavesNextEventToStatusFile:(NSString *)expectedStatus
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
    HCArgumentCaptor * const requestCaptor = [HCArgumentCaptor new];
    [verify(self.URLSessionMock) dataTaskWithRequest:(id)requestCaptor];
    NSURLRequest * const request = (NSURLRequest *)requestCaptor.value;
    assertThat(request.URL, equalTo([NSURL cts_URLWithWebServerConfiguration:self.webServerConfigurationMock
                                                                endpoint:@"refresh_widget"
                                                         queryParameters:@[@"uuid=a-widget-uuid"]]));

    //   And the service starts the task.
    [(NSURLSessionTask *)verify(self.URLSessionTaskMock) resume];
}


#pragma mark - Util

- (void)resetStatusFile
{
    NSError *error = nil;
    [kEmptyTestStatus writeToFile:kTestStatusFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    assertThat(error, nilValue());
}

- (void)mockCalendarEventsWithNextEventTitle:(NSString *)nextEventTitle futureEventTitle:(NSString *)futureEventTitle
{
    self.nextEventMock = mock([EKEvent class]);
    [given(self.nextEventMock.title) willReturn:nextEventTitle];
    [given(self.nextEventMock.startDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:60*60*1.0]];
    [given(self.nextEventMock.endDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:60*60*2.0]];

    self.futureEventMock = mock([EKEvent class]);
    [given(self.futureEventMock.title) willReturn:futureEventTitle];
    [given(self.futureEventMock.startDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:60*60*5.0]];
    [given(self.futureEventMock.endDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:60*60*10.0]];

    self.nextEventPredicateMock = mock([NSPredicate class]);
    [given([self.eventStoreMock predicateForEventsWithStartDate:anything()
                                                        endDate:anything()
                                                      calendars:@[self.calendarMock]])
     willReturn:self.nextEventPredicateMock];

    [givenVoid([self.eventStoreMock enumerateEventsMatchingPredicate:self.nextEventPredicateMock
                                                          usingBlock:notNilValue()])
     willDo:^id _Nonnull(NSInvocation * _Nonnull invocation) {
         EKEventSearchCallback const searchCallback = (EKEventSearchCallback)invocation.mkt_arguments[1];
         BOOL shouldStop = NO;
         searchCallback(self.nextEventMock, &shouldStop);
         assertThatBool(shouldStop, isFalse());
         searchCallback(self.futureEventMock, &shouldStop);
         assertThatBool(shouldStop, isFalse());
         return nil;
     }];
}

@end

NS_ASSUME_NONNULL_END
