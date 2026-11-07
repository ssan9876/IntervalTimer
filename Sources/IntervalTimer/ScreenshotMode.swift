import Foundation

/// Debug builds only: `ci/screenshots.sh` launches the app with `-screenshot <screen>` to open a
/// screen directly, filled with fictional sample data, for the App Store screenshots. Release
/// builds compile all of this out (the build workflow checks), so `screen` is always nil there.
@MainActor
enum ScreenshotMode {
    enum Screen: String {
        case timers, running, finished, log, overview, editor, settings
    }

    nonisolated static var screen: Screen? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "screenshot").flatMap(Screen.init(rawValue:))
        #else
        return nil
        #endif
    }

    nonisolated static var isActive: Bool { screen != nil }

    static var initialTab: AppTab {
        switch screen {
        case .log: .log
        case .overview: .overview
        default: .timers
        }
    }

    /// A complete month reads better than however much of this month has happened so far.
    nonisolated static var initialMonth: Date? {
        guard screen == .overview else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: -1, to: .now)
            .flatMap { calendar.dateInterval(of: .month, for: $0)?.start }
    }

    /// Puts the app on the requested screen once it's on screen.
    static func prepare(engine: TimerEngine) {
        #if DEBUG
        switch screen {
        case .running:
            // Skips "Get Ready" so the shot shows a named interval.
            engine.begin(Workout.samples[2])
            engine.skipForward()
        case .finished:
            engine.begin(Workout.samples[0])
            for _ in engine.segments where !engine.isFinished { engine.skipForward() }
        default:
            break
        }
        #endif
    }

    nonisolated static func sampleSessions() -> [Session] {
        #if DEBUG
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        // (name, category, note, minutes) with fictional notes, cycled through the days.
        let plans: [(String, ActivityCategory, String, Int)] = [
            ("Sprint 20/10", .workout, "Hill sprints before work", 24),
            ("Focus 25/5", .focus, "Finished the quarterly report", 100),
            ("Circuit", .workout, "Leg day", 18),
            ("Meditation", .mindfulness, "Morning wind-down", 10),
            ("Daily Task", .chores, "Cleaned the kitchen", 15),
            ("Focus 25/5", .learning, "Spanish practice", 50),
            ("HIIT 30/30", .workout, "Treadmill intervals", 20),
        ]
        var sessions: [Session] = []
        for offset in 0..<70 {
            // A few rest days, but none in the last week, so the streak looks lived-in.
            if offset > 6 && (offset % 6 == 2 || offset % 11 == 4) { continue }
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let plan = plans[offset % plans.count]
            let count = offset % 4 == 1 ? 2 : 1
            for i in 0..<count {
                let extra = plans[(offset + i * 3) % plans.count]
                let chosen = i == 0 ? plan : extra
                guard let start = calendar.date(bySettingHour: i == 0 ? 7 : 18, minute: 15, second: 0, of: day)
                else { continue }
                sessions.append(Session(
                    workoutName: chosen.0, category: chosen.1, note: chosen.2, start: start,
                    end: start.addingTimeInterval(TimeInterval(chosen.3 * 60)), seconds: chosen.3 * 60))
            }
        }
        return sessions
        #else
        return []
        #endif
    }
}
