import IntervalKit
import Foundation
import SwiftUI

struct IntervalStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var seconds: Int
    var colorIndex: Int
}

struct Workout: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var prepSeconds: Int = 10
    var rounds: Int = 1
    var steps: [IntervalStep]

    var totalSeconds: Int {
        prepSeconds + rounds * steps.reduce(0) { $0 + $1.seconds }
    }

    var summary: String {
        let roundText = rounds == 1 ? "1 round" : "\(rounds) rounds"
        let stepText = steps.count == 1 ? "1 interval" : "\(steps.count) intervals"
        return "\(roundText) · \(stepText) · \(formatTime(totalSeconds))"
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
