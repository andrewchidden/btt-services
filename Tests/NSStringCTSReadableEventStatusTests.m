#import <XCTest/XCTest.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

#import <EventKit/EventKit.h>

#import "NSString+CTSReadableEventStatus.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSStringCTSReadableEventStatusTests : XCTestCase

@end

@implementation NSStringCTSReadableEventStatusTests

- (void)testStringWithTimeInterval
{
    assertThat([NSString cts_stringWithTimeInterval:60*1.0], equalTo(@"1 min"));
    assertThat([NSString cts_stringWithTimeInterval:60*2.33], equalTo(@"2 mins"));
    assertThat([NSString cts_stringWithTimeInterval:60*2.5], equalTo(@"3 mins"));
    assertThat([NSString cts_stringWithTimeInterval:(60*60*0.999)], equalTo(@"1 hr"));
    assertThat([NSString cts_stringWithTimeInterval:(60*60*1.0)], equalTo(@"1 hr"));
    assertThat([NSString cts_stringWithTimeInterval:(60*60*1.33)], equalTo(@"1.3 hrs"));
    assertThat([NSString cts_stringWithTimeInterval:(60*60*2.0)], equalTo(@"2 hrs"));

    assertThat([NSString cts_stringWithTimeInterval:(-60*1.0)], equalTo(@"-1 min"));
    assertThat([NSString cts_stringWithTimeInterval:(-60*2.33)], equalTo(@"-2 mins"));
    assertThat([NSString cts_stringWithTimeInterval:(-60*60*2.0)], equalTo(@"-2 hrs"));
}

- (void)testEventStatusString
{
    // Given an event that has not yet started
    EKEvent * const eventMock = mock([EKEvent class]);
    [given(eventMock.title) willReturn:@"Top Secret Meeting"];
    [given(eventMock.startDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:60*60*1.33]];
    [given(eventMock.endDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:60*60*2.33]];
    // When the category turns the event into a readable string Then the status should be as expected.
    assertThat([NSString cts_stringStatusWithEvent:eventMock referenceDate:[NSDate date]],
               equalTo(@"Top Secret Meeting in 1.3 hrs"));

    // Given an event that has already started
    EKEvent * const startedEventMock = mock([EKEvent class]);
    [given(startedEventMock.title) willReturn:@"Top Secret Meeting"];
    [given(startedEventMock.startDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:-60*60*1.33]];
    [given(startedEventMock.endDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:60*60*1.0]];
    // When the category turns the event into a readable string Then the status should be as expected.
    assertThat([NSString cts_stringStatusWithEvent:startedEventMock referenceDate:[NSDate date]],
               equalTo(@"Top Secret Meeting ending in 1 hr"));
}

- (void)testEventStatusTrimsWhitespace
{
    // Given an event that has leading and trailing whitespace in the title
    EKEvent * const eventMock = mock([EKEvent class]);
    [given(eventMock.title) willReturn:@"  Top Secret Meeting   "];
    [given(eventMock.startDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:60*60*1.33]];
    [given(eventMock.endDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:60*60*2.33]];
    // When the category turns the event into a readable string Then the event title's whitespace should be trimmed.
    assertThat([NSString cts_stringStatusWithEvent:eventMock referenceDate:[NSDate date]],
               equalTo(@"Top Secret Meeting in 1.3 hrs"));
}

- (void)testEventStatusHandlesEndedEvents
{
    // Given an event that has ended
    EKEvent * const eventMock = mock([EKEvent class]);
    [given(eventMock.title) willReturn:@"Top Secret Meeting"];
    [given(eventMock.startDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:-60*60*2.0]];
    [given(eventMock.endDate) willReturn:[NSDate dateWithTimeIntervalSinceNow:-60*60*1.0]];
    // When the category turns the event into a readable string Then the event time should be capped at 0 min.
    assertThat([NSString cts_stringStatusWithEvent:eventMock referenceDate:[NSDate date]],
               equalTo(@"Top Secret Meeting ending in 0 mins"));
}

@end

NS_ASSUME_NONNULL_END
