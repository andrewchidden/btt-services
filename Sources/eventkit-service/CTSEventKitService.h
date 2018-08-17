#import "CTSService.h"

@class EKEventStore;
@class CTSBetterTouchToolWebServerConfiguration;

NS_ASSUME_NONNULL_BEGIN

/**
 A @c CTSEventKitService object can receive event store change notifications and push an update to BTT's webserver.
 */
@interface CTSEventKitService : NSObject <CTSService>

/**
 Create a service.

 @param eventStore The EventKit store used to fetch calendar events and receive update notifications.
 @param notificationCenter The notification center to use for subscribing to calendar event change notifications.
 @param URLSession The URL session to use when pushing requests to BetterTouchTool.
 @param runLoop The run loop used to add and run the update event message timer.
 @param eventLookahead How long to look into the future for events.
 @param statusFilePath The file path to save the latest event status message. Intermediary directories must exist.
 @param noEventsMessage The optional status message to display when there are no events within @c eventLookahead. If
 nil, a default no events message will be shown instead.
 @param calendarNames An optional list of case-sensitive calendar names to check. If nil, all calendars are checked.
 @param widgetUUID An optional widget UUID to push refresh updates after an event changes. If nil, no pushes occur.
 @param webServerConfiguration The optional BetterTouchTool web server configuration object. If nil, no pushes occur.
 @return A new EventKit service instance.
 */
- (instancetype)initWithEventStore:(EKEventStore * const)eventStore
                notificationCenter:(NSNotificationCenter * const)notificationCenter
                        URLSession:(NSURLSession * const)URLSession
                           runLoop:(NSRunLoop * const)runLoop
                    eventLookahead:(NSTimeInterval const)eventLookahead
                    statusFilePath:(NSString * const)statusFilePath
                   noEventsMessage:(nullable NSString * const)noEventsMessage
                     calendarNames:(nullable NSArray<NSString *> * const)calendarNames
                        widgetUUID:(nullable NSString * const)widgetUUID
            webServerConfiguration:(nullable CTSBetterTouchToolWebServerConfiguration * const)webServerConfiguration
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
