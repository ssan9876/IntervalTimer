# Intervals

An iOS interval timer built with SwiftUI. Set up a workout as a list of intervals (name, duration, color) repeated for a number of rounds; each interval starts automatically when the previous one ends.

- **Notifications** for every interval start, scheduled ahead of time so they arrive even when the app is closed. While the iPhone is locked they're mirrored to a paired **Apple Watch**.
- **Live Activity** on the Lock Screen and Dynamic Island (and the Apple Watch Smart Stack on watchOS 11+), counting down the current interval.
- **Audio cues**: 3-2-1 beeps and a chime at each change, mixed over music. While a workout runs the app keeps an audio session open, which keeps it alive in the background so the Live Activity can move on to the next interval.
- Pause, skip forward/back, and runs that survive the app being killed (timer state is timestamp-based and persisted).
- **Workouts and daily tasks**: each timer has a category (Workout, Focus & Work, Chores, Mindfulness, Learning, Other); the + menu has templates (interval workout, Pomodoro, daily task, meditation).
- **Log**: finished runs (and runs ended early after at least a minute) are saved with a note about what they were for, entered on the Done screen. The Log tab lists them by day; tap to edit, + to log something by hand.
- **Today card**: time logged today against a daily goal (Settings), the current streak, and the last 7 days.
- **Overview**: monthly calendar shaded by time per day, totals, best streak, minutes-per-day chart, time per category, most-used timers.
- **Sounds**: built-in sets (Classic, Bell, Digital, Soft Chime), a Voice option that speaks each interval's name, or your own audio files imported from Files. Set a default in Settings, or per timer.

## Layout

| Path | What |
| --- | --- |
| `Sources/IntervalTimer` | The app: models, timer engine, notifications, audio cues, history (`History.swift`, saved to Application Support/history.json), imported sounds (`Sounds.swift`, files in Documents/Sounds), views |
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
