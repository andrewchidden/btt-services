#import <XCTest/XCTest.h>
#import <OCHamcrest/OCHamcrest.h>
#import <OCMockito/OCMockito.h>

#import "NSURL+CTSBetterTouchToolWebServerEndpoint.h"
#import "CTSBetterTouchToolWebServerConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSURLCTSBetterTouchToolWebServerEndpointTests : XCTestCase

@end

@implementation NSURLCTSBetterTouchToolWebServerEndpointTests

- (void)testURLConstructionWithConfiguration
{
    // Given a web server configuration
    CTSBetterTouchToolWebServerConfiguration * const configurationMock =
        mock([CTSBetterTouchToolWebServerConfiguration class]);
    [given(configurationMock.URL) willReturn:[NSURL URLWithString:@"http://127.0.0.1:12345/"]];
    [given(configurationMock.sharedSecret) willReturn:@"a-very-secret-key"];

    // When constructing a new URL to the `refresh_widget` endpoint
    NSURL * const URL = [NSURL cts_URLWithWebServerConfiguration:configurationMock
                                                    endpoint:@"refresh_widget"
                                             queryParameters:@[@"uuid=foo-bar"]];

    // Then the category should use the configuration and parameters to decorate the URL.
    NSURL * const expectedURL =
        [NSURL URLWithString:@"http://127.0.0.1:12345/refresh_widget/?uuid=foo-bar&shared_secret=a-very-secret-key"];
    assertThat(URL, equalTo(expectedURL));
}

@end

NS_ASSUME_NONNULL_END
