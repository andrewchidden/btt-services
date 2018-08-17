#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>

#import "CTSBetterTouchToolWebServerConfiguration.h"
#import "CTSEventKitService.h"

#import "NSDictionary+CTSCommandLineArguments.h"

static NSString * const kCalendarNameDefaultDelimiter = @",";

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSDictionary<NSString *, NSString *> * const dictionary =
            [NSDictionary cts_dictionaryWithCommandLineArguments:[NSProcessInfo processInfo].arguments];
        NSString * _Nullable const eventLookahead = dictionary[@"lookahead"] ?: dictionary[@"l"];
        NSString * _Nullable const statusFilePath = dictionary[@"status-path"] ?: dictionary[@"p"];
        NSString * _Nullable const noEventsMessage = dictionary[@"empty-message"] ?: dictionary[@"m"];
        NSString * _Nullable const webServerURLString = dictionary[@"btt-url"] ?: dictionary[@"u"];
        NSString * _Nullable const webServerSharedSecret = dictionary[@"btt-secret"] ?: dictionary[@"s"];
        NSString * _Nullable const widgetUUID = dictionary[@"widget-uuid"] ?: dictionary[@"w"];
        NSString * _Nullable const calendarNamesString = dictionary[@"calendars"] ?: dictionary[@"c"];
        NSString * _Nullable const calendarNameDelimiter = dictionary[@"delimiter"] ?: dictionary[@"d"];

        if (!statusFilePath ||
            !eventLookahead ||
            (widgetUUID && !webServerURLString)) {
            fputs("Usage: ./eventkit-service\n"
                  "  --lookahead=<minutes>, -l <minutes>\n"
                  "        How long in minutes to look into the future for events.\n\n"

                  "  --status-path=<path>, -p <path>\n"
                  "        The file path to save the latest event status message. Intermediary directories must exist.\n\n"

                  "  --empty-message=<message>, -m <message>\n"
                  "        The status message to show when there are no events within `lookahead`. If not specified,\n"
                  "        a default message will be shown instead when there are no events.\n\n"

                  "  --btt-url=<url>, -u <url>\n"
                  "        The optional base URL to BetterTouchTool's web server in the format `protocol://hostname:port`.\n"
                  "        If not specified, the service will not push updates to BetterTouchTool.\n\n"

                  "  --btt-secret=<secret>, -s <secret>\n"
                  "        The optional shared secret to authenticate with BetterTouchTool's web server.\n\n"

                  "  --widget-uuid=<uuid>, -w <uuid>\n"
                  "        The UUID of the BetterTouchTool widget to refresh on update pushes. If not specified, the\n"
                  "        service will not push updates to BetterTouchTool.\n\n"

                  "  --calendars=<names>, -c <names>\n"
                  "        An optional comma delimited list of case-sensitive calendar names to check for events. If\n"
                  "        not specified, the service checks all calendars for events.\n\n"

                  "  --delimiter=<delim>, -d <delim>\n"
                  "        The optional string delimiter to use for separating calendar names. If not specified, the\n"
                  "        service will use comma for the calendar name list delimiter.\n\n", stderr);
            return 1;
        }

        NSURL * const webServerURL = [NSURL URLWithString:webServerURLString];
        CTSBetterTouchToolWebServerConfiguration * const configuration =
            [[CTSBetterTouchToolWebServerConfiguration alloc] initWithURL:webServerURL
                                                             sharedSecret:webServerSharedSecret];

        NSTimeInterval const eventLookaheadSeconds = eventLookahead.integerValue * 60.0;
        NSString * const nameDelimiter = calendarNameDelimiter ?: kCalendarNameDefaultDelimiter;
        NSArray<NSString *> * const calendarNames = [calendarNamesString componentsSeparatedByString:nameDelimiter];

        EKEventStore * const eventStore = [EKEventStore new];
        NSNotificationCenter * const notificationCenter = [NSNotificationCenter defaultCenter];
        NSURLSession * const URLSession = [NSURLSession sharedSession];
        NSRunLoop * const runLoop = [NSRunLoop currentRunLoop];
        CTSEventKitService * const service = [[CTSEventKitService alloc] initWithEventStore:eventStore
                                                                         notificationCenter:notificationCenter
                                                                                 URLSession:URLSession
                                                                                    runLoop:runLoop
                                                                             eventLookahead:eventLookaheadSeconds
                                                                             statusFilePath:statusFilePath
                                                                            noEventsMessage:noEventsMessage
                                                                              calendarNames:calendarNames
                                                                                 widgetUUID:widgetUUID
                                                                     webServerConfiguration:configuration];
        [service start];

        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        while (service.isRunning) {
            [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    }
    return 0;
}
