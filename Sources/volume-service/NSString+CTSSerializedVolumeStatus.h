#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (CTSSerializedVolumeStatus)

/**
 Create a serialized volume string.

 @param volume The volume to serialize, from 0 to 100 inclusive.
 @param muteState Whether or not the output volume is muted.
 @return A positive integer (between 0 and 100 inclusive) as a string if not muted, or negative if muted.
 */
+ (NSString *)cts_stringStatusWithVolume:(int const)volume muteState:(BOOL)muteState;

@end

NS_ASSUME_NONNULL_END
