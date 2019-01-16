#import <Foundation/Foundation.h>

#import "NSDictionary+CTSCommandLineArguments.h"
#import "CTSControlStripService.h"

static NSString * const kCalendarNameDefaultDelimiter = @",";

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSDictionary<NSString *, NSString *> * const dictionary =
            [NSDictionary cts_dictionaryWithCommandLineArguments:[NSProcessInfo processInfo].arguments];
        NSString * _Nullable const typeString = dictionary[@"type"] ?: dictionary[@"t"];
        NSString * _Nullable const directionString = dictionary[@"direction"] ?: dictionary[@"d"];

        if (!typeString ||
            !directionString) {
            fputs("Usage: ./controlstrip-service\n"
                  "  --type=<volume|brightness>, -t <volume|brightness>\n"
                  "        The class of keyboard events to handle. Should be either `volume` or `brightness`.\n"
                  "        - `volume` modifier key behavior:\n"
                  "              [None] Adjusts volume.\n"
                  "              [Shift] Plays feedback sound.\n"
                  "              [Option] Opens Volume preference pane in System Preferences.\n"
                  "              [Shift+Option] Small volume adjustments.\n"
                  "        - `brightness` modifier key behavior:\n"
                  "              [None] Adjusts screen brightness.\n"
                  "              [Shift] Changes keyboard illumination.\n"
                  "              [Option] Opens Displays preference pane in System Preferences.\n"
                  "              [Shift+Option] Small screen brightness adjustments.\n\n"

                  "  --direction=<dir>, -d <dir>\n"
                  "        The direction of the change, either 0 or 1, where 0 is decrement, 1 is increment.\n\n",
                  stderr);
            return 1;
        }

        BOOL const isVolumeType = [typeString isEqualToString:@"volume"];
        BOOL const shouldIncrement = directionString.boolValue;

        CTSControlStripControlType type;
        if (isVolumeType) {
            type = (shouldIncrement ? CTSControlStripVolumeUpControl : CTSControlStripVolumeDownControl);
        } else {
            type = (shouldIncrement ? CTSControlStripBrightnessUpControl : CTSControlStripBrightnessDownControl);
        }

        NSEventModifierFlags const modifierFlags = [NSEvent modifierFlags];
        NSWorkspace * const workspace = [NSWorkspace sharedWorkspace];
        CTSControlStripService * const service =
            [[CTSControlStripService alloc] initWithControlType:type
                                                  modifierFlags:modifierFlags
                                                      workspace:workspace];
        [service start];
    }
    return 0;
}
