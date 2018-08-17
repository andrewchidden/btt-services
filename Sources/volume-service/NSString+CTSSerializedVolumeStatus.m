#import "NSString+CTSSerializedVolumeStatus.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSString (CTSSerializedVolumeStatus)

+ (NSString *)cts_stringStatusWithVolume:(const int)volume muteState:(BOOL)muteState
{
    NSString *status = nil;
    if (muteState && volume == 0) {
        status = @"-0";
    } else {
        status = [NSString stringWithFormat:@"%d", (muteState ? -1 : 1) * volume];
    }
    return status;
}

@end

NS_ASSUME_NONNULL_END
