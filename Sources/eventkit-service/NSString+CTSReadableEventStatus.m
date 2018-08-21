#import "NSString+CTSReadableEventStatus.h"
#import <EventKit/EventKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSString (CTSReadableEventStatus)

+ (NSString *)cts_stringWithRoundedTimeInterval:(NSTimeInterval const)timeInterval units:(NSString * const)units
{
    NSString *readableInterval = nil;
    if (fmod(timeInterval, 1.0) == 0) {
        readableInterval = [NSString stringWithFormat:@"%d %@", (int)(timeInterval), units];
    } else {
        readableInterval = [NSString stringWithFormat:@"%.1f %@", timeInterval, units];
    }
    if (fabs(timeInterval) != 1) {
        readableInterval = [readableInterval stringByAppendingString:@"s"];
    }
    return readableInterval;
}

+ (NSString *)cts_stringWithTimeInterval:(NSTimeInterval const)timeInterval
{
    if (round(fabs(timeInterval) / 60.0) < 60.0) {
        NSTimeInterval minutes = round(timeInterval / 60.0);
        return [NSString cts_stringWithRoundedTimeInterval:minutes units:@"min"];
    } else {
        NSTimeInterval hours = round(timeInterval / 60.0 / 60.0 * 10.0) / 10.0;
        return [NSString cts_stringWithRoundedTimeInterval:hours units:@"hr"];
    }
}

+ (NSString *)cts_stringStatusWithEvent:(EKEvent * const)event referenceDate:(NSDate * const)referenceDate
{
    BOOL const hasEventStarted = ([referenceDate compare:event.startDate] == NSOrderedDescending || NSOrderedSame);
    NSString * const trimmedTitle =
        [event.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSString *formattedOutput = nil;
    if (hasEventStarted) {
        NSString * const readableInterval =
            [NSString cts_stringWithTimeInterval:MAX(0, [event.endDate timeIntervalSinceDate:referenceDate])];
        formattedOutput = [NSString stringWithFormat:@"%@ ending in %@", trimmedTitle, readableInterval];
    } else {
        NSString * const readableInterval =
            [NSString cts_stringWithTimeInterval:MAX(0, [event.startDate timeIntervalSinceDate:referenceDate])];
        formattedOutput = [NSString stringWithFormat:@"%@ in %@", trimmedTitle, readableInterval];
    }
    return formattedOutput;
}

@end

NS_ASSUME_NONNULL_END
