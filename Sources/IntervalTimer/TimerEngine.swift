import Foundation
import IntervalKit
import SwiftUI
import UIKit

/// Persisted state of the active run. Elapsed time is derived from timestamps, so the
/// timer stays correct while the app is suspended or even killed.
struct RunState: Codable {
    var workout: Workout
    /// Elapsed seconds accumulated up to `anchor` (or in total while paused).
    var offset: TimeInterval
    /// When the clock last started running; nil while paused or finished.
    var anchor: Date?
    /// When the run was started (nil for runs saved by older versions).
    var startedAt: Date?
    /// The history entry for this run, once it's been logged.
    var loggedSessionID: UUID?
}

enum SettingsKey {
    static let keepAwake = "keepAwake"
    static let audioCues = "audioCues"
    static let defaultSound = "defaultSound"
    static let dailyGoalMinutes = "dailyGoalMinutes"

    static var audioCuesEnabled: Bool {
        UserDefaults.standard.object(forKey: audioCues) as? Bool ?? true
    }

    static var defaultCueSound: CueSound {
        UserDefaults.standard.string(forKey: defaultSound).flatMap(CueSound.init(id:)) ?? .default
    }
}

@MainActor
final class TimerEngine: ObservableObject {
    private static let key = "activeRun.v1"
    /// Runs ended early are only logged if they lasted at least this long.
    private static let minimumLoggedSeconds = 60

    @Published private(set) var run: RunState? {
        didSet { persist() }
    }
    @Published private(set) var now = Date()

    private(set) var segments: [Segment] = []
    private var lastIndex: Int?
    private var lastCountdownBeep: (index: Int, second: Int)?
    private var ticker: Task<Void, Never>?
    private let liveActivity = LiveActivityController()
    private let audio = AudioCues()
    private let history: HistoryStore

    init(history: HistoryStore) {
        self.history = history
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(RunState.self, from: data) {
            run = saved
            segments = saved.workout.segments
            lastIndex = currentIndex
            if isFinished {
                // Finished while the app wasn't running.
                logSession(completed: true, end: finishDate)
                run = nil
                segments = []
                persist() // didSet doesn't run in init; don't log it again next launch.
            } else if isRunning {
                audio.start()
                startTicking()
            }
        }
        syncLiveActivity()
    }

    // MARK: Derived state

    var workout: Workout? { run?.workout }
    var isRunning: Bool { run?.anchor != nil }
    var total: TimeInterval { TimeInterval(segments.last?.end ?? 0) }

    var elapsed: TimeInterval {
        guard let run else { return 0 }
        let e = run.anchor.map { run.offset + now.timeIntervalSince($0) } ?? run.offset
        return min(max(e, 0), total)
    }

    var isFinished: Bool { run != nil && elapsed >= total }
    var currentIndex: Int? {
        let e = elapsed
        return segments.firstIndex { e < TimeInterval($0.end) }
    }
    var currentSegment: Segment? { currentIndex.map { segments[$0] } }
    var nextSegment: Segment? {
        guard let i = currentIndex, i + 1 < segments.count else { return nil }
        return segments[i + 1]
    }
    var remainingInSegment: TimeInterval {
        guard let s = currentSegment else { return 0 }
        return TimeInterval(s.end) - elapsed
    }
    var segmentProgress: Double {
        guard let s = currentSegment, s.seconds > 0 else { return 1 }
        return min(max((elapsed - TimeInterval(s.start)) / TimeInterval(s.seconds), 0), 1)
    }
    var totalRemaining: TimeInterval { total - elapsed }
    var loggedSessionID: UUID? { run?.loggedSessionID }

    private var cueSound: CueSound { run?.workout.cueSound ?? .default }

    /// When the run reached (or will reach) its end at the current pace.
    private var finishDate: Date {
        guard let run, let anchor = run.anchor else { return now }
        return anchor.addingTimeInterval(total - run.offset)
    }

    // MARK: Controls

    func start(_ workout: Workout) {
        let segs = workout.segments
        guard !segs.isEmpty else { return }
        segments = segs
        now = Date()
        run = RunState(workout: workout, offset: 0, anchor: now, startedAt: now)
        lastIndex = 0
        lastCountdownBeep = nil
        Notifier.clearDelivered()
        reschedule()
        audio.start()
        startTicking()
        announceTransition()
    }

    func pause() {
        guard var r = run, let anchor = r.anchor else { return }
        now = Date()
        r.offset = min(r.offset + now.timeIntervalSince(anchor), total)
        r.anchor = nil
        run = r
        Notifier.cancelPending()
        stopTicking()
        audio.stop()
        syncLiveActivity()
    }

    func resume() {
        guard var r = run, r.anchor == nil, !isFinished else { return }
        now = Date()
        r.anchor = now
        run = r
        reschedule()
        audio.start()
        startTicking()
        syncLiveActivity()
    }

    func togglePause() {
        isRunning ? pause() : resume()
    }

    func restart() {
        guard let workout else { return }
        start(workout)
    }

    func stop() {
        if run != nil {
            now = Date()
            if !isFinished { logSession(completed: false, end: now) }
        }
        stopTicking()
        Notifier.cancelPending()
        audio.stop()
        run = nil
        segments = []
        lastIndex = nil
        syncLiveActivity()
    }

    func skipForward() {
        guard let i = currentIndex else { return }
        seek(to: TimeInterval(segments[i].end))
    }

    /// Restarts the current interval, or jumps to the previous one if we're within its first 2 seconds.
    func skipBack() {
        guard !segments.isEmpty else { return }
        let i = currentIndex ?? segments.count - 1
        let into = elapsed - TimeInterval(segments[i].start)
        let target = (into < 2 && i > 0) ? segments[i - 1].start : segments[i].start
        seek(to: TimeInterval(target))
    }

    /// Call when the app returns to the foreground so transitions that happened in the
    /// background (already announced by notifications) don't trigger a haptic.
    func resync() {
        guard run != nil else { return }
        now = Date()
        lastIndex = currentIndex
        if isRunning && isFinished {
            finish(cancelPending: false, announce: false)
        } else {
            syncLiveActivity()
        }
    }

    // MARK: Internals

    private func seek(to t: TimeInterval) {
        guard var r = run else { return }
        now = Date()
        r.offset = min(max(t, 0), total)
        if r.anchor != nil { r.anchor = now }
        run = r
        lastIndex = currentIndex
        lastCountdownBeep = nil
        if isFinished {
            finish(cancelPending: true, announce: true)
            return
        }
        if isRunning { reschedule() }
        announceTransition()
    }

    private func finish(cancelPending: Bool, announce: Bool) {
        guard var r = run else { return }
        let end = finishDate
        r.offset = total
        r.anchor = nil
        run = r
        logSession(completed: true, end: end)
        stopTicking()
        if cancelPending { Notifier.cancelPending() }
        var cueLength: TimeInterval = 0
        if announce {
            Haptics.finished()
            if SettingsKey.audioCuesEnabled { cueLength = audio.finishedCue(cueSound) }
        }
        audio.stop(after: max(1.5, min(cueLength, 10) + 0.3))
        syncLiveActivity()
    }

    /// Adds the run to the history (once). Time in "Get Ready" doesn't count.
    private func logSession(completed: Bool, end: Date) {
        guard var r = run, r.loggedSessionID == nil else { return }
        let prep = segments.first.map { $0.round == 0 ? $0.seconds : 0 } ?? 0
        let seconds = max(0, Int((completed ? total : elapsed).rounded()) - prep)
        guard completed || seconds >= Self.minimumLoggedSeconds else { return }
        let session = Session(
            workoutID: r.workout.id, workoutName: r.workout.name, category: r.workout.category,
            start: r.startedAt ?? end.addingTimeInterval(-TimeInterval(seconds + prep)), end: end,
            seconds: seconds, completed: completed)
        history.upsert(session)
        r.loggedSessionID = session.id
        run = r
    }

    private func tick() {
        now = Date()
        if isFinished {
            if isRunning { finish(cancelPending: false, announce: true) }
            return
        }
        guard let index = currentIndex else { return }
        if index != lastIndex {
            lastIndex = index
            announceTransition()
        } else if SettingsKey.audioCuesEnabled, segments[index].seconds > 3 {
            // 3-2-1 countdown into the next interval.
            let second = Int(remainingInSegment.rounded(.up))
            if (1...3).contains(second), lastCountdownBeep.map({ $0 != (index, second) }) ?? true {
                lastCountdownBeep = (index, second)
                audio.countdownBeep(cueSound)
            }
        }
    }

    private func announceTransition() {
        Haptics.transition()
        if SettingsKey.audioCuesEnabled, isRunning, let segment = currentSegment {
            audio.transitionCue(cueSound, name: segment.name)
        }
        syncLiveActivity()
    }

    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    private func reschedule() {
        guard let workout else { return }
        Notifier.schedule(segments: segments, workout: workout, elapsed: elapsed)
    }

    private func syncLiveActivity() {
        guard let run else {
            liveActivity.end()
            return
        }
        if isFinished {
            let done = IntervalActivityAttributes.ContentState(
                name: "Done!", colorIndex: 0, round: 0, rounds: run.workout.rounds, next: nil,
                segmentStart: now, segmentEnd: now, isPaused: false, pausedRemaining: 0,
                pausedProgress: 1, isFinished: true)
            liveActivity.end(finalState: done, dismissAt: now.addingTimeInterval(120))
            return
        }
        guard let segment = currentSegment else { return }
        let e = elapsed
        let segmentEnd = now.addingTimeInterval(TimeInterval(segment.end) - e)
        let state = IntervalActivityAttributes.ContentState(
            name: segment.name, colorIndex: segment.colorIndex, round: segment.round,
            rounds: run.workout.rounds, next: nextSegment?.name,
            segmentStart: now.addingTimeInterval(TimeInterval(segment.start) - e), segmentEnd: segmentEnd,
            isPaused: !isRunning, pausedRemaining: Int(remainingInSegment.rounded(.up)),
            pausedProgress: segmentProgress, isFinished: false)
        // If the app gets killed mid-run, the lock screen dims itself instead of showing 0:00.
        liveActivity.show(state, workoutName: run.workout.name,
                          staleDate: isRunning ? segmentEnd.addingTimeInterval(3) : nil)
    }

    private func persist() {
        if let run, let data = try? JSONEncoder().encode(run) {
            UserDefaults.standard.set(data, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }
}

@MainActor
enum Haptics {
    static func transition() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func finished() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
