#import <Foundation/Foundation.h>

#import "NSDictionary+CTSCommandLineArguments.h"
#import "CTSBetterTouchToolWebServerConfiguration.h"
#import "CTSVolumeService.h"

static NSString * const kCalendarNameDefaultDelimiter = @",";

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSDictionary<NSString *, NSString *> * const dictionary =
            [NSDictionary cts_dictionaryWithCommandLineArguments:[NSProcessInfo processInfo].arguments];
        NSString * _Nullable const statusFilePath = dictionary[@"status-path"] ?: dictionary[@"p"];
        NSString * _Nullable const useThresholdChangesString = dictionary[@"use-threshold"] ?: dictionary[@"u"];
        NSString * _Nullable const thresholdsString = dictionary[@"thresholds"] ?: dictionary[@"t"];
        NSString * _Nullable const webServerURLString = dictionary[@"btt-url"] ?: dictionary[@"u"];
        NSString * _Nullable const webServerSharedSecret = dictionary[@"btt-secret"] ?: dictionary[@"s"];
        NSString * _Nullable const widgetUUID = dictionary[@"widget-uuid"] ?: dictionary[@"w"];

        if (!statusFilePath ||
            !useThresholdChangesString ||
            (widgetUUID && !webServerURLString)) {
            fputs("Usage: ./volume-service\n"
                  "  --status-path=<path>, -p <path>\n"
                  "        The file path to save the latest volume state. Intermediary directories must exist.\n\n"

                  "  --btt-url=<url>, -u <url>\n"
                  "        The optional base URL to BetterTouchTool's web server in the format `protocol://hostname:port`.\n"
                  "        If not specified, the service will not push updates to BetterTouchTool.\n\n"

                  "  --btt-secret=<secret>, -s <secret>\n"
                  "        The optional shared secret to authenticate with BetterTouchTool's web server.\n\n"

                  "  --widget-uuid=<uuid>, -w <uuid>\n"
                  "        The UUID of the BetterTouchTool widget to refresh on update pushes. If not specified, the\n"
                  "        service will not push updates to BetterTouchTool.\n\n"

                  "  --use-threshold=<bool>, -u <bool>\n"
                  "        Whether to only treat changes between volume appearance thresholds as valid events. See\n"
                  "        also, `--thresholds, -t`.\n\n"

                  "  --thresholds=<num_list>, -t <num_list>\n"
                  "        An optional list of comma-delimited, strictly-greater-than thresholds in descending order.\n"
                  "        If not specified, [65,32,0] is used instead, corresponding to the system thresholds.\n\n",
                  stderr);
            return 1;
        }

        NSURL * const webServerURL = [NSURL URLWithString:webServerURLString];
        CTSBetterTouchToolWebServerConfiguration * const configuration =
            [[CTSBetterTouchToolWebServerConfiguration alloc] initWithURL:webServerURL
                                                             sharedSecret:webServerSharedSecret];

        BOOL const useThresholdChanges = useThresholdChangesString.boolValue;
        NSMutableArray<NSNumber *> *thresholds = (useThresholdChanges ? [NSMutableArray array] : nil);
        if (useThresholdChanges) {
            NSArray<NSString *> * const thresholdStringComponents = [thresholdsString componentsSeparatedByString:@","];
            for (NSString * const thresholdString in thresholdStringComponents) {
                [thresholds addObject:@([thresholdString integerValue])];
            }
            if (thresholds.count == 0) {
                thresholds = [@[@65, @32, @0] mutableCopy];
            }
        }

        NSURLSession * const URLSession = [NSURLSession sharedSession];
        CTSVolumeService * const service = [[CTSVolumeService alloc] initWithStatusFilePath:statusFilePath
                                                                                 URLSession:URLSession
                                                                                 widgetUUID:widgetUUID
                                                                     webServerConfiguration:configuration
                                                                           volumeThresholds:thresholds];
        [service start];

        NSRunLoop * const runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        while (service.isRunning) {
            [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    }
    return 0;
}
