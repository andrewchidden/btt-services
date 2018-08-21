#import <XCTest/XCTest.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

#import <EventKit/EventKit.h>

#import "EKEvent+CTSVisibility.h"

NS_ASSUME_NONNULL_BEGIN

@interface EKEventConcreteMock : EKEvent

@property (nonatomic, assign, readwrite) EKEventAvailability availability;
@property (nonatomic, assign, readwrite) EKEventStatus status;

@end

@implementation EKEventConcreteMock

@synthesize availability = _availability, status = _status;

@end

@interface EKEventCTSVisibilityTests : XCTestCase

@end

@implementation EKEventCTSVisibilityTests

- (void)testVisibilityForAvailability
{
    // Given an event
    EKEventConcreteMock * const event = [EKEventConcreteMock new];
    //   With a non-canceled status
    event.status = EKEventStatusConfirmed;

    // When the availability is free
    event.availability = EKEventAvailabilityFree;
    // Then the event visibility should be NO.
    assertThatBool(event.isVisible, isFalse());

    // And When the availability is tenative
    event.availability = EKEventAvailabilityTentative;
    // Then the event visibility should be YES.
    assertThatBool(event.isVisible, isTrue());

    // And When the availability is not supported
    event.availability = EKEventAvailabilityNotSupported;
    // Then the event visibility should be YES.
    assertThatBool(event.isVisible, isTrue());

    // And When the availability is busy
    event.availability = EKEventAvailabilityBusy;
    // Then the event visibility should be YES.
    assertThatBool(event.isVisible, isTrue());
}

- (void)testVisibilityForStatus
{
    // Given an event
    EKEventConcreteMock * const event = [EKEventConcreteMock new];
    // When the event status is canceled
    event.status = EKEventStatusCanceled;
    // Then the event availability should be NO regardless of availability.
    event.availability = EKEventAvailabilityFree;
    assertThatBool(event.isVisible, isFalse());
    event.availability = EKEventAvailabilityTentative;
    assertThatBool(event.isVisible, isFalse());
    event.availability = EKEventAvailabilityNotSupported;
    assertThatBool(event.isVisible, isFalse());
    event.availability = EKEventAvailabilityBusy;
    assertThatBool(event.isVisible, isFalse());
}


@end

NS_ASSUME_NONNULL_END
