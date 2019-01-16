btt-services
============

Simple command-line utilities designed for BetterTouchTool presets. Able to use BetterTouchTool’s integrated web server to send low-latency refresh widget messages.

Most utilities require controller scripts for appearance state and process persistence, which can be found at [andrewchidden/btt-controllers](https://github.com/andrewchidden/btt-controllers).

Article about the preset at [andrewchidden.com](https://andrewchidden.com/long-live-the-macbook-pro-with-touch-bar/).

## EventKit Service

### About

Observes `EventKit` for changes and outputs the upcoming calendar event information in a readable text format. May be extended to read reminders in the future.

### API

```
Usage: ./eventkit-service
  --lookahead=<minutes>, -l <minutes>
        How long in minutes to look into the future for events.

  --status-path=<path>, -p <path>
        The file path to save the latest event status message. Intermediary directories must exist.

  --empty-message=<message>, -m <message>
        The status message to show when there are no events within `lookahead`. If not specified,
        a default message will be shown instead when there are no events.

  --btt-url=<url>, -u <url>
        The optional base URL to BetterTouchTool's web server in the format `protocol://hostname:port`.
        If not specified, the service will not push updates to BetterTouchTool.

  --btt-secret=<secret>, -s <secret>
        The optional shared secret to authenticate with BetterTouchTool's web server.

  --widget-uuid=<uuid>, -w <uuid>
        The UUID of the BetterTouchTool widget to refresh on update pushes. If not specified, the
        service will not push updates to BetterTouchTool.

  --calendars=<names>, -c <names>
        An optional comma delimited list of case-sensitive calendar names to check for events. If
        not specified, the service checks all calendars for events.

  --delimiter=<delim>, -d <delim>
        The optional string delimiter to use for separating calendar names. If not specified, the
        service will use comma for the calendar name list delimiter.
```

## Volume Service

### About

Listens for volume changes from `CoreAudio` and outputs a serialized device volume state.

### API

```
Usage: ./volume-service
  --status-path=<path>, -p <path>
        The file path to save the latest volume state. Intermediary directories must exist.

  --btt-url=<url>, -u <url>
        The optional base URL to BetterTouchTool's web server in the format `protocol://hostname:port`.
        If not specified, the service will not push updates to BetterTouchTool.

  --btt-secret=<secret>, -s <secret>
        The optional shared secret to authenticate with BetterTouchTool's web server.

  --widget-uuid=<uuid>, -w <uuid>
        The UUID of the BetterTouchTool widget to refresh on update pushes. If not specified, the
        service will not push updates to BetterTouchTool.

  --use-threshold=<bool>, -u <bool>
        Whether to only treat changes between volume appearance thresholds as valid events. See
        also, `--thresholds, -t`.

  --thresholds=<num_list>, -t <num_list>
        An optional list of comma-delimited, strictly-greater-than thresholds in descending order.
        If not specified, [65,32,0] is used instead, corresponding to the system thresholds.
```

## Control Strip Service

### About

Replicates system-level keyboard buttons (volume, brightness) and additional side effects (feedback sound, open preference pane) based on the current set of modifier keys (shift, option).

### API

```
Usage: ./controlstrip-service
  --type=<volume|brightness>, -t <volume|brightness>
        The class of keyboard events to handle. Should be either `volume` or `brightness`.
        - `volume` modifier key behavior:
              [None] Adjusts volume.
              [Shift] Plays feedback sound.
              [Option] Opens Volume preference pane in System Preferences.
              [Shift+Option] Small volume adjustments.
        - `brightness` modifier key behavior:
              [None] Adjusts screen brightness.
              [Shift] Changes keyboard illumination.
              [Option] Opens Displays preference pane in System Preferences.
              [Shift+Option] Small screen brightness adjustments.

  --direction=<dir>, -d <dir>
        The direction of the change, either 0 or 1, where 0 is decrement, 1 is increment.
```

## Building from Source

1. Download and install the latest version of [Xcode](https://developer.apple.com/xcode/).
2. Open `./btt-services.xcodeproj`.
3. Build each target (for Running = **debug**, for Profiling = **release**).

## Contributing

Contributions welcomed. Some ground rules:

- Please ensure that you follow the style of the codebase which takes inspiration from [Google’s Objective-C style guide](https://google.github.io/styleguide/objcguide.html).
- Add unit tests for all core service functionality. This project uses [OCMockito](https://github.com/jonreid/OCMockito) for general-purpose mocking and verification.
	- To test services that use C-style function APIs, create a stub and forward invocations to a concrete mock. Examples can be found in `./Tests/Stubs`.
	- Keep code coverage of services and service utilities above 95%, using the [code coverage feature](https://www.bignerdranch.com/blog/weve-got-you-covered/) in Xcode.

## Contact

```
"andrew"
"@"
"andrewchidden.com"
```

## License

Copyright © 2018 CarbonTech Software LLC

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.