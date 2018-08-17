#import <XCTest/XCTest.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

#import "NSDictionary+CTSCommandLineArguments.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionaryCTSCommandLineArgumentsTests : XCTestCase

@end

@implementation NSDictionaryCTSCommandLineArgumentsTests

- (void)testCommandLineArgumentsParsedIntoDictionary
{
    // Given an array of command-line arguments
    NSArray<NSString *> * const commandLineArgumentsMock = @[
        @"/usr/local/bin/foo-bar-service",
        @"--foo=bar",
        @"-k", @"value",
        @"--one=plus two = three",
        @"not-an-argument",
    ];

    // When the category parses the command-line arguments
    NSDictionary<NSString *, NSString *> * const argumentsDictionary =
        [NSDictionary cts_dictionaryWithCommandLineArguments:commandLineArgumentsMock];

    // Then the dictionary should have the expectedkey-value option pairs.
    assertThat(argumentsDictionary, equalTo(@{
        @"foo" : @"bar",
        @"k" : @"value",
        @"one" : @"plus two = three",
    }));
}

- (void)testAlwaysIgnoresFirstArgument
{
    assertThat([NSDictionary cts_dictionaryWithCommandLineArguments:@[@"--ignored=argument"]], equalTo(@{}));
}

@end

NS_ASSUME_NONNULL_END
