import ActivityKit
import Foundation
import IntervalKit

/// Drives the lock screen / Dynamic Island / Apple Watch Smart Stack Live Activity.
///
/// Requests run in order, and all ActivityKit calls happen off the main thread: they are
/// synchronous XPC round trips that have been seen hanging the main thread at launch.
@MainActor
final class LiveActivityController {
    typealias State = IntervalActivityAttributes.ContentState

    private let store = LiveActivityStore()
    private var pending: Task<Void, Never>?

    func show(_ state: State, workoutName: String, staleDate: Date?) {
        enqueue { [store] in await store.show(state, workoutName: workoutName, staleDate: staleDate) }
    }

    /// Ends every activity of this app; `dismissAt` nil removes it right away.
    func end(finalState: State? = nil, dismissAt: Date? = nil) {
        enqueue { [store] in await store.end(finalState: finalState, dismissAt: dismissAt) }
    }

    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        let previous = pending
        pending = Task {
            await previous?.value
            await work()
        }
    }
}

/// Activity objects aren't Sendable, so they're looked up fresh for each call rather than stored.
private actor LiveActivityStore {
    func show(_ state: IntervalActivityAttributes.ContentState, workoutName: String, staleDate: Date?) async {
        let content = ActivityContent(state: state, staleDate: staleDate, relevanceScore: 100)

        // Also picks up an activity a previous process started before being relaunched.
        for activity in Activity<IntervalActivityAttributes>.activities where activity.activityState == .active {
            if activity.attributes.workoutName == workoutName {
                await activity.update(content)
                return
            }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(attributes: IntervalActivityAttributes(workoutName: workoutName),
                                  content: content, pushType: nil)
    }

    func end(finalState: IntervalActivityAttributes.ContentState?, dismissAt: Date?) async {
        let content = finalState.map { ActivityContent(state: $0, staleDate: nil) }
        let policy: ActivityUIDismissalPolicy = dismissAt.map { .after($0) } ?? .immediate
        for activity in Activity<IntervalActivityAttributes>.activities {
            await activity.end(content, dismissalPolicy: policy)
        }
    }
}
