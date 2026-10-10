# Intervals

An iOS interval timer built with SwiftUI. Set up a workout as a list of intervals (name, duration, color) repeated for a number of rounds; each interval starts automatically when the previous one ends.

- **Notifications** for every interval start, scheduled ahead of time so they arrive even when the app is closed. While the iPhone is locked they're mirrored to a paired **Apple Watch**.
- **Live Activity** on the Lock Screen and Dynamic Island (and the Apple Watch Smart Stack on watchOS 11+), counting down the current interval.
- **Audio cues**: 3-2-1 beeps and a chime at each change, mixed over music. While a workout runs the app keeps an audio session open, which keeps it alive in the background so the Live Activity can move on to the next interval.
- Pause, skip forward/back, and runs that survive the app being killed (timer state is timestamp-based and persisted).

## Layout

| Path | What |
| --- | --- |
| `Sources/IntervalTimer` | The app: models, timer engine, notifications, audio cues, views |
| `Sources/IntervalTimerWidget` | Live Activity widget extension |
| `Sources/IntervalKit` | Shared between both: Live Activity attributes, colors, time formatting |
| `xtool.yml`, `Info.plist`, `Widget-Info.plist` | App and extension metadata |

## Building

Built with [xtool](https://github.com/xtool-org/xtool) (no Xcode needed), iOS 18+.

```bash
xtool dev build   # build only
xtool dev         # build, sign and install on a connected device
```

Note for the widget extension: xtool links extensions with `_NSExtensionMain` as the entry point, and the `@main` `WidgetBundle` lives in a library, so `Package.swift` passes `-Xlinker -u -Xlinker _main` to keep it from being dropped. Don't make `_main` the entry point instead; the extension then crashes at launch.
