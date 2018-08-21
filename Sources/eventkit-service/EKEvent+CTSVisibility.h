#import <EventKit/EventKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EKEvent (CTSVisibility)

/// Whether or not the event should be visible on the calendar.
@property (nonatomic, assign, readonly, getter=isVisible) BOOL visible;

@end

NS_ASSUME_NONNULL_END
