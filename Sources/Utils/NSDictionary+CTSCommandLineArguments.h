#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (CTSCommandLineArguments)

/**
 Convert an array of @c NSString command-line arguments, such as those from @c NSProcessInfo into key-value pairs.

 @note Only supports options in the format `--key=value` and `-k value`.

 @param arguments An array containing the command-line arguments as strings.
 @return A dictionary of the command-line arguments as key-value pairs for each option and its value.
 */
+ (NSDictionary<NSString *, NSString *> *)cts_dictionaryWithCommandLineArguments:(NSArray<NSString *> * const)arguments;

@end

NS_ASSUME_NONNULL_END
