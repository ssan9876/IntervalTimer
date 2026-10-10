import ActivityKit
import Foundation
import SwiftUI

// Code shared by the app and the Live Activity widget extension.

public enum Palette {
    public static let colors: [Color] = [.green, .red, .blue, .orange, .purple, .teal, .pink, .indigo, .gray]
    public static let prepIndex = 8

    public static func color(_ index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}

public func formatTime(_ totalSeconds: Int) -> String {
    let s = max(0, totalSeconds)
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}

public struct IntervalActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var name: String
        public var colorIndex: Int
        /// 0 for "Get Ready".
        public var round: Int
        public var rounds: Int
        public var next: String?
        /// Wall-clock bounds of the current interval while running, so the widget can count
        /// down on its own between updates.
        public var segmentStart: Date
        public var segmentEnd: Date
        public var isPaused: Bool
        public var pausedRemaining: Int
        public var pausedProgress: Double
        public var isFinished: Bool

        public init(name: String, colorIndex: Int, round: Int, rounds: Int, next: String?,
                    segmentStart: Date, segmentEnd: Date, isPaused: Bool, pausedRemaining: Int,
                    pausedProgress: Double, isFinished: Bool) {
            self.name = name
            self.colorIndex = colorIndex
            self.round = round
            self.rounds = rounds
            self.next = next
            self.segmentStart = segmentStart
            self.segmentEnd = max(segmentStart, segmentEnd)
            self.isPaused = isPaused
            self.pausedRemaining = pausedRemaining
            self.pausedProgress = pausedProgress
            self.isFinished = isFinished
        }

        public var color: Color { isFinished ? .green : Palette.color(colorIndex) }

        public var detail: String {
            if isFinished { return "Workout complete" }
            var parts: [String] = []
            if round > 0 { parts.append("Round \(round)/\(rounds)") }
            parts.append(next.map { "Next: \($0)" } ?? "Last interval")
            return parts.joined(separator: " · ")
        }
    }

    public var workoutName: String

    public init(workoutName: String) {
        self.workoutName = workoutName
    }
}
