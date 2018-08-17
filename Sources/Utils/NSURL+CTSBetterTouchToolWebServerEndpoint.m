#import "NSURL+CTSBetterTouchToolWebServerEndpoint.h"
#import "CTSBetterTouchToolWebServerConfiguration.h"

static NSString * const kSharedSecretQueryParameterKey = @"shared_secret";

NS_ASSUME_NONNULL_BEGIN

@implementation NSURL (CTSBetterTouchToolWebServerEndpoint)

+ (NSURL *)cts_URLWithWebServerConfiguration:(CTSBetterTouchToolWebServerConfiguration * const)webServerConfiguration
                                    endpoint:(NSString * const)endpoint
                             queryParameters:(nullable NSArray<NSString *> * const)queryParameters
{
    NSString *URLString = [webServerConfiguration.URL URLByAppendingPathComponent:endpoint].absoluteString;
    if (![URLString hasSuffix:@"/"]) { // DRAGON: BetterTouchTool requires endpoints to be at the directory level.
        URLString = [URLString stringByAppendingString:@"/"];
    }
    NSURLComponents * const components = [NSURLComponents componentsWithString:URLString];
    NSMutableArray * const decoratedQueryParameters = [(queryParameters ?: @[]) mutableCopy];
    if (webServerConfiguration.sharedSecret) {
        [decoratedQueryParameters addObject:[NSString stringWithFormat:@"%@=%@",
                                             kSharedSecretQueryParameterKey, webServerConfiguration.sharedSecret]];
    }
    NSString * const queryParameterString = [(decoratedQueryParameters ?: @[]) componentsJoinedByString:@"&"];
    components.query = queryParameterString;
    return components.URL;
}

@end

NS_ASSUME_NONNULL_END
