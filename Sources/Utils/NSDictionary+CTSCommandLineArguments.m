#import "NSDictionary+CTSCommandLineArguments.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSDictionary (CTSCommandLineArguments)

+ (NSDictionary<NSString *,NSString *> *)cts_dictionaryWithCommandLineArguments:(NSArray<NSString *> * const)arguments
{
    NSMutableDictionary<NSString *, NSString *> * const argumentsDictionary = [NSMutableDictionary dictionary];

    for (NSInteger index = 1; index < arguments.count; index++) {
        NSString * const argument = arguments[index];
        if ([argument rangeOfString:@"--"].location != NSNotFound &&
            [argument rangeOfString:@"="].location != NSNotFound) { // `--key=value`
            NSArray * const components = [argument componentsSeparatedByString:@"="];
            NSString * const key =
                [[components objectAtIndex:0] stringByReplacingOccurrencesOfString:@"--" withString:@""];
            NSIndexSet * const indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, components.count-1)];
            NSString * const value = [[components objectsAtIndexes:indexSet] componentsJoinedByString:@"="];

            argumentsDictionary[key] = value;
        } else if ([argument rangeOfString:@"-"].location == 0) { // `-k value`
            NSString * const key = [argument stringByReplacingOccurrencesOfString:@"-" withString:@""];
            NSString * const value = [arguments objectAtIndex:(index + 1)];

            argumentsDictionary[key] = value;
        }
    }
    
    return argumentsDictionary;
}

@end

NS_ASSUME_NONNULL_END
