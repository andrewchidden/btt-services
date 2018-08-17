#import "CTSCoreGraphicsEventControlStripServiceTestStub.h"

void CGEventPost(CGEventTapLocation tap, CGEventRef __nullable event)
{
}

@implementation CTSCoreGraphicsEventMock

- (void)cgEventPost:(CGEventTapLocation)tap event:(CGEventRef __nullable)event
{
}

@end
