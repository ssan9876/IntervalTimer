import ActivityKit
import IntervalKit
import SwiftUI
import WidgetKit

@main
struct IntervalTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        IntervalLiveActivity()
    }
}

struct IntervalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IntervalActivityAttributes.self) { context in
            ActivityView(context: context)
                .activityBackgroundTint(context.state.color)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.name)
                            .font(.title3.bold())
                            .foregroundStyle(state.color)
                            .lineLimit(1)
                        Text(context.attributes.workoutName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(state: state)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        SegmentProgress(state: state)
                            .tint(state.color)
                        Text(state.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle().fill(state.color).frame(width: 8, height: 8)
                    Text(state.name)
                        .font(.caption.bold())
                        .lineLimit(1)
                        .frame(maxWidth: 64, alignment: .leading)
                }
            } compactTrailing: {
                CountdownText(state: state)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44, alignment: .trailing)
                    .foregroundStyle(state.color)
            } minimal: {
                Image(systemName: state.isFinished ? "checkmark" : (state.isPaused ? "pause.fill" : "timer"))
                    .foregroundStyle(state.color)
            }
            .keylineTint(state.color)
        }
        // .small is the layout Apple Watch uses in its Smart Stack (watchOS 11+).
        .supplementalActivityFamilies([.small, .medium])
    }
}

struct ActivityView: View {
    let context: ActivityViewContext<IntervalActivityAttributes>
    @Environment(\.activityFamily) private var family

    var body: some View {
        let state = context.state
        switch family {
        case .small:
            // Apple Watch Smart Stack.
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(state.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if state.round > 0 {
                        Text("\(state.round)/\(state.rounds)")
                            .font(.caption2.bold())
                            .opacity(0.8)
                    }
                }
                CountdownText(state: state)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                SegmentProgress(state: state)
                    .tint(.white)
            }
            .foregroundStyle(.white)
            .padding(10)
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.workoutName)
                            .font(.caption.weight(.semibold))
                            .opacity(0.8)
                        Text(state.name)
                            .font(.title.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(state.detail)
                            .font(.subheadline)
                            .opacity(0.85)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    CountdownText(state: state)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 150, alignment: .trailing)
                }
                SegmentProgress(state: state)
                    .tint(.white)
                if state.isPaused {
                    Label("Paused", systemImage: "pause.fill")
                        .font(.caption.bold())
                } else if context.isStale && !state.isFinished {
                    Text("Open Intervals to sync")
                        .font(.caption.bold())
                }
            }
            .foregroundStyle(.white)
            .padding(16)
        }
    }
}

/// Counts down by itself between updates while running.
struct CountdownText: View {
    let state: IntervalActivityAttributes.ContentState

    var body: some View {
        if state.isFinished {
            Text("Done")
        } else if state.isPaused {
            Text(formatTime(state.pausedRemaining))
        } else {
            Text(timerInterval: state.segmentStart...state.segmentEnd, countsDown: true)
        }
    }
}

struct SegmentProgress: View {
    let state: IntervalActivityAttributes.ContentState

    var body: some View {
        if state.isFinished || state.isPaused {
            ProgressView(value: state.isFinished ? 1 : state.pausedProgress)
        } else {
            ProgressView(timerInterval: state.segmentStart...state.segmentEnd, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        }
    }
}
