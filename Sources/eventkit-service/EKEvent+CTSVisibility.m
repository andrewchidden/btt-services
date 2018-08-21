#import "EKEvent+CTSVisibility.h"

NS_ASSUME_NONNULL_BEGIN

@implementation EKEvent (CTSVisibility)

- (BOOL)isVisible
{
    BOOL const isConfirmed = self.availability != EKEventAvailabilityFree
                          || self.availability == EKEventAvailabilityNotSupported;
    BOOL const isValid = (self.status != EKEventStatusCanceled); // See docs on `status`.
    return (isConfirmed && isValid);
}

@end

NS_ASSUME_NONNULL_END
