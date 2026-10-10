import IntervalKit
import Foundation
import UserNotifications

/// Schedules one local notification per upcoming interval start. iOS delivers them even when
/// the app is suspended or killed, and mirrors them to a paired Apple Watch while the iPhone
/// is locked, so the Watch taps your wrist at every interval without needing a watchOS app.
enum Notifier {
    /// iOS keeps at most 64 pending notifications per app; one is reserved for "complete".
    private static let maxIntervalNotifications = 63
    private static let threadID = "interval-run"

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    static func schedule(segments: [Segment], workout: Workout, elapsed: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        var requests: [UNNotificationRequest] = []
        for (i, segment) in segments.enumerated() where TimeInterval(segment.start) > elapsed + 0.25 {
            guard requests.count < maxIntervalNotifications else { break }
            let content = UNMutableNotificationContent()
            content.title = "\(segment.name) · \(formatTime(segment.seconds))"
            var details: [String] = []
            if segment.round > 0 {
                details.append("Round \(segment.round) of \(workout.rounds)")
            }
            details.append(i + 1 < segments.count ? "Next: \(segments[i + 1].name)" : "Last interval")
            content.body = details.joined(separator: " · ")
            content.sound = .default
            content.threadIdentifier = threadID
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(segment.start) - elapsed, repeats: false)
            requests.append(UNNotificationRequest(identifier: "segment-\(i)", content: content, trigger: trigger))
        }

        let total = TimeInterval(segments.last?.end ?? 0)
        if total - elapsed > 0.25 {
            let content = UNMutableNotificationContent()
            content.title = "Workout complete"
            content.body = "\(workout.name) · \(formatTime(Int(total)))"
            content.sound = .default
            content.threadIdentifier = threadID
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: total - elapsed, repeats: false)
            requests.append(UNNotificationRequest(identifier: "complete", content: content, trigger: trigger))
        }

        for request in requests {
            center.add(request, withCompletionHandler: nil)
        }
    }

    static func cancelPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func clearDelivered() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

/// While the app is open there's no banner; the app's own beeps replace the notification
/// sound unless audio cues are turned off.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        SettingsKey.audioCuesEnabled ? [.list] : [.sound, .list]
    }
}
