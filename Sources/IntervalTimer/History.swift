import Foundation

/// One use of a timer (or a manual entry), with a note about what it was for.
struct Session: Identifiable, Codable, Hashable {
    var id = UUID()
    var workoutID: UUID?
    var workoutName: String
    var category: ActivityCategory
    var note: String = ""
    var start: Date
    var end: Date
    /// Time spent in intervals, not counting "Get Ready".
    var seconds: Int
    /// False when the run was ended before its last interval.
    var completed: Bool = true

    static func manual() -> Session {
        let now = Date()
        return Session(workoutName: "", category: .workout, start: now.addingTimeInterval(-30 * 60),
                       end: now, seconds: 30 * 60)
    }
}

/// Totals for one calendar month, for the overview screen.
struct MonthSummary {
    var sessions: [Session]
    var daily: [Date: Int]
    var totalSeconds: Int
    var longestStreak: Int
    var byCategory: [(category: ActivityCategory, seconds: Int)]
    var byTimer: [(name: String, count: Int, seconds: Int)]

    var activeDays: Int { daily.count }
}

@MainActor
final class HistoryStore: ObservableObject {
    /// Newest first.
    @Published private(set) var sessions: [Session] = [] {
        didSet { rebuildDaily() }
    }
    /// Seconds per day (keyed by start of day), for days with at least one session.
    private(set) var daily: [Date: Int] = [:]

    private var saveTask: Task<Void, Never>?
    private var calendar: Calendar { .current }

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "history.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([Session].self, from: data) {
            sessions = saved.sorted { $0.start > $1.start }
        }
        rebuildDaily()
    }

    // MARK: Editing

    func session(id: UUID) -> Session? {
        sessions.first { $0.id == id }
    }

    /// Adds the session, or replaces the one with the same id.
    func upsert(_ session: Session) {
        var all = sessions.filter { $0.id != session.id }
        all.append(session)
        sessions = all.sorted { $0.start > $1.start }
        scheduleSave()
    }

    func update(id: UUID, _ change: (inout Session) -> Void) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        change(&sessions[i])
        scheduleSave()
    }

    func delete(id: UUID) {
        sessions.removeAll { $0.id == id }
        scheduleSave()
    }

    /// Writes pending changes now (e.g. when the app goes to the background).
    func save() {
        saveTask?.cancel()
        saveTask = nil
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    /// Coalesces saves, since the finish screen edits the note a keystroke at a time.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    // MARK: Stats

    private func rebuildDaily() {
        var result: [Date: Int] = [:]
        for s in sessions {
            result[calendar.startOfDay(for: s.start), default: 0] += s.seconds
        }
        daily = result
    }

    /// Days that have sessions, newest first.
    var days: [Date] {
        daily.keys.sorted(by: >)
    }

    func sessions(on day: Date) -> [Session] {
        sessions.filter { calendar.isDate($0.start, inSameDayAs: day) }
    }

    func seconds(on day: Date) -> Int {
        daily[calendar.startOfDay(for: day)] ?? 0
    }

    /// Consecutive days with a session, counting back from today (or from yesterday if
    /// nothing is logged yet today, so the streak doesn't look broken in the morning).
    func currentStreak(today: Date = .now) -> Int {
        var day = calendar.startOfDay(for: today)
        if daily[day] == nil {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while daily[day] != nil {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    func summary(forMonthContaining date: Date) -> MonthSummary {
        let month = calendar.dateInterval(of: .month, for: date)!
        let monthSessions = sessions.filter { month.contains($0.start) && $0.start < month.end }
        let monthDaily = daily.filter { $0.key >= month.start && $0.key < month.end }

        var longest = 0, run = 0
        var day = month.start
        while day < month.end {
            run = monthDaily[day] != nil ? run + 1 : 0
            longest = max(longest, run)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }

        var categories: [ActivityCategory: Int] = [:]
        var timers: [String: (count: Int, seconds: Int)] = [:]
        for s in monthSessions {
            categories[s.category, default: 0] += s.seconds
            let name = s.workoutName.isEmpty ? "Untitled" : s.workoutName
            let t = timers[name] ?? (0, 0)
            timers[name] = (t.count + 1, t.seconds + s.seconds)
        }

        return MonthSummary(
            sessions: monthSessions,
            daily: monthDaily,
            totalSeconds: monthSessions.reduce(0) { $0 + $1.seconds },
            longestStreak: longest,
            byCategory: categories.map { (category: $0.key, seconds: $0.value) }.sorted { $0.seconds > $1.seconds },
            byTimer: timers.map { (name: $0.key, count: $0.value.count, seconds: $0.value.seconds) }
                .sorted { ($0.seconds, $0.count) > ($1.seconds, $1.count) }
        )
    }
}

/// Compact duration for stats: "45s", "25m", "1h 20m".
func formatDuration(_ seconds: Int) -> String {
    let s = max(0, seconds)
    if s < 60 { return "\(s)s" }
    let m = s / 60
    if m < 60 { return "\(m)m" }
    return m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m"
}
