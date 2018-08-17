#import <Foundation/Foundation.h>
#import <CoreGraphics/CGEventTypes.h>

CG_EXTERN void CGEventPost(CGEventTapLocation tap, CGEventRef __nullable event) __attribute__((weak));

/**
 A @c CTSCoreGraphicsEventMock object provides Objective-C method bindings between the test runner and OCMockito.
 */
@interface CTSCoreGraphicsEventMock : NSObject

- (void)cgEventPost:(CGEventTapLocation)tap event:(CGEventRef __nullable)event;

@end
