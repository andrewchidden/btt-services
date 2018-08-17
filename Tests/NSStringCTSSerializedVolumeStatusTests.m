#import <XCTest/XCTest.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

#import "NSString+CTSSerializedVolumeStatus.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSStringCTSSerializedVolumeStatusTests : XCTestCase

@end

@implementation NSStringCTSSerializedVolumeStatusTests

- (void)testStringWithTimeInterval
{
    assertThat([NSString cts_stringStatusWithVolume:0 muteState:NO], equalTo(@"0"));
    assertThat([NSString cts_stringStatusWithVolume:30 muteState:NO], equalTo(@"30"));
    assertThat([NSString cts_stringStatusWithVolume:0 muteState:YES], equalTo(@"-0"));
    assertThat([NSString cts_stringStatusWithVolume:30 muteState:YES], equalTo(@"-30"));
}

@end

NS_ASSUME_NONNULL_END
