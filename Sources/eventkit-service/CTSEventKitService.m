#import <EventKit/EventKit.h>

#import "CTSEventKitService.h"
#import "CTSBetterTouchToolWebServerConfiguration.h"

#import "NSURL+CTSBetterTouchToolWebServerEndpoint.h"
#import "EKEvent+CTSVisibility.h"
#import "NSString+CTSReadableEventStatus.h"
#import "CTSWeakify.h"

NS_ASSUME_NONNULL_BEGIN

static NSTimeInterval const kUpdateEventMessageTimerInterval = 15.0;
static NSString * const kNoEventsDefaultStatusMessage = @"No upcoming meetings";
static NSString * const kBetterTouchToolRefreshWidgetEndpoint = @"refresh_widget";

@interface CTSEventKitService ()

@property (nonatomic, strong, readonly) EKEventStore *eventStore;
@property (nonatomic, strong, readonly) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong, readonly) NSURLSession *URLSession;
@property (nonatomic, strong, readonly) NSRunLoop *runLoop;
@property (nonatomic, assign, readonly) NSTimeInterval eventLookahead;
@property (nonatomic, strong, readonly) NSString *statusFilePath;
@property (nonatomic, strong, readonly) NSString *noEventsMessage;
@property (nonatomic, strong, readonly, nullable) NSString *widgetUUID;
@property (nonatomic, strong, readonly, nullable) CTSBetterTouchToolWebServerConfiguration *webServerConfiguration;
@property (nonatomic, strong, readwrite) NSArray<EKCalendar *> *calendars;
@property (nonatomic, strong, readonly) NSArray<NSString *> *calendarNames;
@property (nonatomic, strong, readonly) NSTimer *updateTimer;

@property (nonatomic, strong, readwrite, nullable) EKEvent *nextEvent;
@property (nonatomic, assign, readwrite) CFAbsoluteTime lastStatusSaveTime;
@property (nonatomic, strong, readwrite, nullable) NSString *lastSavedStatus;

@end

@implementation CTSEventKitService

@synthesize running = _running;

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
{
    self = [super init];

    if (self) {
        _eventStore = eventStore;
        _notificationCenter = notificationCenter;
        _URLSession = URLSession;
        _eventLookahead = eventLookahead;
        _statusFilePath = statusFilePath;
        _noEventsMessage = noEventsMessage ?: kNoEventsDefaultStatusMessage;
        _calendarNames = calendarNames ?: @[];
        _widgetUUID = widgetUUID;
        _webServerConfiguration = webServerConfiguration;
        _runLoop = runLoop;

        weakify(self);
        strongify(self);
        _updateTimer = [NSTimer timerWithTimeInterval:kUpdateEventMessageTimerInterval
                                               target:self
                                             selector:@selector(saveNextEventToStatusFile)
                                             userInfo:nil
                                              repeats:YES];
    }

    return self;
}

- (void)start
{
    _running = YES;
    weakify(self);
    [self.eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL const granted, NSError * const error) {
        strongify(self);
        if (!granted || error) {
#if DEBUG
            NSLog(@"No calendar access, granted: %d, error: %@", granted, error);
#endif
            self->_running = NO;
            return;
        }

        [self setUpService];
    }];
}

/// Set up done after receiving calendar access permissions.
- (void)setUpService
{
    [self.runLoop addTimer:self.updateTimer forMode:NSRunLoopCommonModes];

    self.calendars = [self fetchCalendarsWithNames:self.calendarNames];
    [self addCalendarObserver];

    // Immediately update status file with latest event information.
    [self updateNextEvent];
}


#pragma mark - EventKit notification handling

- (void)addCalendarObserver
{
    [self.notificationCenter addObserver:self
                                selector:@selector(eventStoreChanged:)
                                    name:EKEventStoreChangedNotification
                                  object:self.eventStore];
}

- (void)eventStoreChanged:(NSNotification * const)notification
{
#if DEBUG
    NSLog(@"Handling event store change");
#endif
    [self updateNextEvent];
}

- (void)updateNextEvent
{
    self.nextEvent = [self fetchNextEvent];
    [self saveNextEventToStatusFile];
}


#pragma mark - Update and notify BTT

- (void)saveNextEventToStatusFile
{
    if (self.nextEvent) {
        BOOL const hasEventEnded = ([[NSDate date] compare:self.nextEvent.endDate] == NSOrderedDescending);
        if (hasEventEnded) {
            self.nextEvent = nil;
        }
    }

    NSString *status = (self.nextEvent ? [NSString cts_stringStatusWithEvent:self.nextEvent referenceDate:[NSDate date]]
                                       :  self.noEventsMessage);
    if ([status isEqualToString:self.lastSavedStatus]) {
        return;
    }

    NSError *error = nil;
    [status writeToFile:self.statusFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!error) {
        self.lastSavedStatus = status;
        self.lastStatusSaveTime = CFAbsoluteTimeGetCurrent();
    }

#if DEBUG
    NSLog(@"Saved status to status file, status: %@, file path: %@, error: %@", status, self.statusFilePath, error);
#endif

    [self pushUpdateToWidget];
}

- (void)pushUpdateToWidget
{
    if (!self.webServerConfiguration || !self.widgetUUID) {
        return;
    }

    NSURL * const URL = [NSURL cts_URLWithWebServerConfiguration:self.webServerConfiguration
                                                    endpoint:kBetterTouchToolRefreshWidgetEndpoint
                                             queryParameters:@[[NSString stringWithFormat:@"uuid=%@",self.widgetUUID]]];
    NSURLRequest * const request = [NSURLRequest requestWithURL:URL
                                                    cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                timeoutInterval:1.0];
    NSURLSessionTask * const task = [self.URLSession dataTaskWithRequest:request];
    [task resume];

#if DEBUG
    NSLog(@"Pushed update to BTT web server at URL: %@", URL);
#endif
}


#pragma mark - EventKit utils

- (NSArray<EKCalendar *> *)fetchCalendarsWithNames:(NSArray<NSString *> * const)calendarNames
{
    NSArray<EKCalendar *> * const calendarArray = [self.eventStore calendarsForEntityType:EKEntityTypeEvent];
    NSMutableArray<EKCalendar *> * const filteredArray = [NSMutableArray arrayWithCapacity:calendarArray.count];
    for (EKCalendar * const calendar in calendarArray) {
        if ([calendarNames containsObject:calendar.title]) {
            [filteredArray addObject:calendar];
        }
    }
    return filteredArray;
}

- (nullable EKEvent *)fetchNextEvent
{
    NSDate * const endDate = [NSDate dateWithTimeIntervalSinceNow:self.eventLookahead];
    NSPredicate * const predicate = [self.eventStore predicateForEventsWithStartDate:[NSDate date]
                                                                             endDate:endDate
                                                                           calendars:self.calendars];
    NSMutableArray<EKEvent *> * const eventsArray = [NSMutableArray array];
    [self.eventStore enumerateEventsMatchingPredicate:predicate usingBlock:^(EKEvent * const event, BOOL *stop) {
        if (event.isVisible) {
            [eventsArray addObject:event];
        }
    }];

    EKEvent * const firstEvent =
        [eventsArray sortedArrayUsingSelector:@selector(compareStartDateWithEvent:)].firstObject;
    return firstEvent;
}

@end

NS_ASSUME_NONNULL_END
