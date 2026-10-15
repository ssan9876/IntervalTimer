import IntervalKit
import Foundation
import SwiftUI

struct IntervalStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var seconds: Int
    var colorIndex: Int
}

/// What a timer (and each logged session) is used for; drives the monthly breakdown.
enum ActivityCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case workout, focus, chores, mindfulness, learning, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workout: "Workout"
        case .focus: "Focus & Work"
        case .chores: "Chores"
        case .mindfulness: "Mindfulness"
        case .learning: "Learning"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .workout: "figure.run"
        case .focus: "laptopcomputer"
        case .chores: "house.fill"
        case .mindfulness: "leaf.fill"
        case .learning: "book.fill"
        case .other: "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .workout: .red
        case .focus: .blue
        case .chores: .orange
        case .mindfulness: .teal
        case .learning: .purple
        case .other: .gray
        }
    }

    init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .other
    }
}

struct Workout: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var prepSeconds: Int = 10
    var rounds: Int = 1
    var steps: [IntervalStep]
    var category: ActivityCategory = .workout
    /// A `CueSound` id, or nil to use the default from Settings.
    var sound: String?

    enum CodingKeys: String, CodingKey {
        case id, name, prepSeconds, rounds, steps, category, sound
    }

    var totalSeconds: Int {
        prepSeconds + rounds * steps.reduce(0) { $0 + $1.seconds }
    }

    var summary: String {
        let roundText = rounds == 1 ? "1 round" : "\(rounds) rounds"
        let stepText = steps.count == 1 ? "1 interval" : "\(steps.count) intervals"
        return "\(roundText) · \(stepText) · \(formatTime(totalSeconds))"
    }

    var cueSound: CueSound {
        sound.flatMap(CueSound.init(id:)) ?? SettingsKey.defaultCueSound
    }

    /// The full run flattened into a timeline: optional "Get Ready", then every step for every round.
    var segments: [Segment] {
        var result: [Segment] = []
        var t = 0
        if prepSeconds > 0 {
            result.append(Segment(name: "Get Ready", seconds: prepSeconds, colorIndex: Palette.prepIndex, round: 0, start: 0))
            t = prepSeconds
        }
        for round in 1...max(rounds, 1) {
            for step in steps where step.seconds > 0 {
                let name = step.name.trimmingCharacters(in: .whitespaces)
                result.append(Segment(name: name.isEmpty ? "Interval" : name, seconds: step.seconds,
                                      colorIndex: step.colorIndex, round: round, start: t))
                t += step.seconds
            }
        }
        return result
    }
}

extension Workout {
    // In an extension so the memberwise initializer is kept. Fields added after v1 are optional
    // in saved data, so existing workouts keep loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        prepSeconds = try c.decodeIfPresent(Int.self, forKey: .prepSeconds) ?? 10
        rounds = try c.decodeIfPresent(Int.self, forKey: .rounds) ?? 1
        steps = try c.decode([IntervalStep].self, forKey: .steps)
        category = try c.decodeIfPresent(ActivityCategory.self, forKey: .category) ?? .workout
        sound = try c.decodeIfPresent(String.self, forKey: .sound)
    }
}

struct Segment: Hashable {
    var name: String
    var seconds: Int
    var colorIndex: Int
    /// 0 for the "Get Ready" segment.
    var round: Int
    /// Offset in seconds from the start of the workout.
    var start: Int
    var end: Int { start + seconds }
}

extension Workout {
    static var blank: Workout {
        Workout(name: "New Workout", prepSeconds: 10, rounds: 3, steps: [
            IntervalStep(name: "Work", seconds: 30, colorIndex: 1),
            IntervalStep(name: "Rest", seconds: 15, colorIndex: 0),
        ])
    }

    /// Starting points offered by the + menu. Computed so each one gets fresh ids.
    static var templates: [(title: String, icon: String, workout: Workout)] {
        [
            ("Interval Workout", "figure.run", blank),
            ("Pomodoro Focus", "laptopcomputer", Workout(
                name: "Pomodoro", prepSeconds: 5, rounds: 4, steps: [
                    IntervalStep(name: "Focus", seconds: 25 * 60, colorIndex: 2),
                    IntervalStep(name: "Break", seconds: 5 * 60, colorIndex: 0),
                ], category: .focus)),
            ("Daily Task", "checklist", Workout(
                name: "Daily Task", prepSeconds: 5, rounds: 1, steps: [
                    IntervalStep(name: "Task", seconds: 15 * 60, colorIndex: 3),
                ], category: .chores)),
            ("Meditation", "leaf.fill", Workout(
                name: "Meditation", prepSeconds: 10, rounds: 1, steps: [
                    IntervalStep(name: "Breathe", seconds: 10 * 60, colorIndex: 5),
                ], category: .mindfulness, sound: CueSound.tone(.bell).id)),
        ]
    }

    static let samples: [Workout] = [
        Workout(name: "Tabata", prepSeconds: 10, rounds: 8, steps: [
            IntervalStep(name: "Work", seconds: 20, colorIndex: 1),
            IntervalStep(name: "Rest", seconds: 10, colorIndex: 0),
        ]),
        Workout(name: "HIIT 30/30", prepSeconds: 10, rounds: 10, steps: [
            IntervalStep(name: "Sprint", seconds: 30, colorIndex: 3),
            IntervalStep(name: "Recover", seconds: 30, colorIndex: 2),
        ]),
        Workout(name: "Circuit", prepSeconds: 10, rounds: 3, steps: [
            IntervalStep(name: "Squats", seconds: 45, colorIndex: 1),
            IntervalStep(name: "Rest", seconds: 15, colorIndex: 0),
            IntervalStep(name: "Push-ups", seconds: 45, colorIndex: 3),
            IntervalStep(name: "Rest", seconds: 15, colorIndex: 0),
            IntervalStep(name: "Plank", seconds: 45, colorIndex: 4),
            IntervalStep(name: "Round Break", seconds: 60, colorIndex: 2),
        ]),
        Workout(name: "Pomodoro", prepSeconds: 5, rounds: 4, steps: [
            IntervalStep(name: "Focus", seconds: 25 * 60, colorIndex: 2),
            IntervalStep(name: "Break", seconds: 5 * 60, colorIndex: 0),
        ], category: .focus),
    ]
}

@MainActor
final class WorkoutStore: ObservableObject {
    private static let key = "workouts.v1"

    @Published var workouts: [Workout] {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Workout].self, from: data) {
            workouts = saved
        } else {
            workouts = Workout.samples
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(workouts) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
