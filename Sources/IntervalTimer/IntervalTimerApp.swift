import SwiftUI
import UserNotifications

@main
struct IntervalTimerApp: App {
    @StateObject private var store = WorkoutStore()
    @StateObject private var history: HistoryStore
    @StateObject private var sounds = SoundLibrary()
    @StateObject private var engine: TimerEngine

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // The engine logs finished runs into the history, so they share one store.
        let history = HistoryStore()
        _history = StateObject(wrappedValue: history)
        _engine = StateObject(wrappedValue: TimerEngine(history: history))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(history)
                .environmentObject(sounds)
                .environmentObject(engine)
        }
    }
}
