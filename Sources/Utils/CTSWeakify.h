/// @see http://holko.pl/2015/05/31/weakify-strongify/

#define weakify(var) __weak typeof(var) CTSWeak_##var = var;

#define strongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = CTSWeak_##var; \
_Pragma("clang diagnostic pop")
