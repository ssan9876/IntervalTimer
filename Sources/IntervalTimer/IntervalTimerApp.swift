import SwiftUI
import UserNotifications

@main
struct IntervalTimerApp: App {
    @StateObject private var store = WorkoutStore()
    @StateObject private var engine = TimerEngine()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(engine)
        }
    }
}
