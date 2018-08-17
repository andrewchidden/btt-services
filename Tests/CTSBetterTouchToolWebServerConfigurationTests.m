#import <XCTest/XCTest.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

#import "CTSBetterTouchToolWebServerConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface CTSBetterTouchToolWebServerConfigurationTests : XCTestCase

@end

@implementation CTSBetterTouchToolWebServerConfigurationTests

- (void)testConfigurationInitialization
{
    NSURL * const URL = [NSURL URLWithString:@"http://127.0.0.1:12345"];
    NSString * const sharedSecret = @"a-very-secret-key";
    CTSBetterTouchToolWebServerConfiguration * const configuration =
        [[CTSBetterTouchToolWebServerConfiguration alloc] initWithURL:URL sharedSecret:sharedSecret];
    assertThat(configuration.URL, equalTo(URL));
    assertThat(configuration.sharedSecret, equalTo(sharedSecret));
}

@end

NS_ASSUME_NONNULL_END
