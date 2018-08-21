#import <Foundation/Foundation.h>

@class EKEvent;

NS_ASSUME_NONNULL_BEGIN

@interface NSString (CTSReadableEventStatus)

/**
 Create a readable string that rounds time intervals in a smart manner.

 @param timeInterval The time interval to convert to a readable string.
 @return A readable representation of the time interval, rounded to the nearest tenth: 1.25 -> "1.3"; 1.0 -> "1".
 */
+ (NSString *)cts_stringWithTimeInterval:(NSTimeInterval const)timeInterval;

/**
 Create a full string status message from an event, based on

 @param event The event to use for start and end dates.
 @param referenceDate The date to use to use as the reference point to create the relative times.
 @return A string status in the format "{event_title} in {readable_time}" or "{event_title} ending in {readable_time}".
 */
+ (NSString *)cts_stringStatusWithEvent:(EKEvent * const)event referenceDate:(NSDate * const)referenceDate;

@end

NS_ASSUME_NONNULL_END
