import IntervalKit
import SwiftUI
import UIKit

struct RunnerView: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var history: HistoryStore
    @AppStorage(SettingsKey.keepAwake) private var keepAwake = false
    @State private var note = ""
    @State private var category = ActivityCategory.workout
    @FocusState private var noteFocused: Bool

    var body: some View {
        let segment = engine.currentSegment
        let finished = engine.isFinished

        ZStack {
            backgroundColor(segment: segment, finished: finished)
                .ignoresSafeArea()
                .onTapGesture { noteFocused = false }

            VStack(spacing: 16) {
                header
                Spacer()
                if finished {
                    finishedContent
                } else if let segment {
                    activeContent(segment)
                }
                Spacer()
                if !finished {
                    controls
                }
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .animation(.easeInOut(duration: 0.35), value: engine.currentIndex)
        .animation(.easeInOut(duration: 0.35), value: finished)
        .onChange(of: engine.isRunning, initial: true) { _, running in
            UIApplication.shared.isIdleTimerDisabled = keepAwake && running
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func backgroundColor(segment: Segment?, finished: Bool) -> Color {
        if finished { return .green }
        return segment.map { Palette.color($0.colorIndex) } ?? .gray
    }

    private var header: some View {
        HStack {
            Text(engine.workout?.name ?? "")
                .font(.headline)
                .opacity(0.9)
            Spacer()
            Button {
                saveLog()
                engine.stop()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.bold())
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: Circle())
            }
            .accessibilityLabel("End workout")
        }
    }

    private func activeContent(_ segment: Segment) -> some View {
        VStack(spacing: 14) {
            Text(segment.name.uppercased())
                .font(.system(size: 44, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if segment.round > 0 {
                Text("Round \(segment.round) of \(engine.workout?.rounds ?? 1)")
                    .font(.title3.weight(.semibold))
                    .opacity(0.85)
            }

            Text(formatTime(Int(engine.remainingInSegment.rounded(.up))))
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText(countsDown: true))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.white)
                        .frame(width: proxy.size.width * engine.segmentProgress)
                }
            }
            .frame(height: 10)

            Text(engine.nextSegment.map { "Next: \($0.name) · \(formatTime($0.seconds))" } ?? "Last interval")
                .font(.headline)
                .opacity(0.85)

            if !engine.isRunning {
                Text("PAUSED")
                    .font(.headline.weight(.heavy))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.25), in: Capsule())
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 44) {
                Button(action: engine.skipBack) {
                    Image(systemName: "backward.end.fill")
                        .font(.title)
                        .frame(width: 56, height: 56)
                }
                .accessibilityLabel("Previous interval")

                Button(action: engine.togglePause) {
                    Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 36))
                        .frame(width: 88, height: 88)
                        .background(.white.opacity(0.25), in: Circle())
                }
                .accessibilityLabel(engine.isRunning ? "Pause" : "Resume")

                Button(action: engine.skipForward) {
                    Image(systemName: "forward.end.fill")
                        .font(.title)
                        .frame(width: 56, height: 56)
                }
                .accessibilityLabel("Next interval")
            }

            Text("\(formatTime(Int(engine.totalRemaining.rounded(.up)))) remaining")
                .font(.subheadline.monospacedDigit())
                .opacity(0.8)
        }
    }

    private var finishedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: noteFocused ? 44 : 80))
            Text("Done!")
                .font(.system(size: 48, weight: .heavy))
            Text("\(engine.workout?.name ?? "") · \(formatTime(Int(engine.total)))")
                .font(.headline)
                .opacity(0.85)
            if engine.loggedSessionID != nil {
                logEditor
            }
            HStack(spacing: 16) {
                Button {
                    saveLog()
                    engine.restart()
                } label: {
                    Label("Again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    saveLog()
                    engine.stop()
                } label: {
                    Label("Finish", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.headline)
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.large)
            .padding(.top, 12)
        }
        .animation(.easeInOut(duration: 0.25), value: noteFocused)
        .onChange(of: engine.loggedSessionID, initial: true) { _, id in
            guard let id, let session = history.session(id: id) else { return }
            note = session.note
            category = session.category
        }
        .onDisappear(perform: saveLog)
    }

    /// "What was this for?": a note and category for the run that was just logged.
    private var logEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What was this for?")
                .font(.subheadline.weight(.semibold))
            TextField("", text: $note,
                      prompt: Text("e.g. Leg day, study session, cleaning").foregroundStyle(.white.opacity(0.6)))
                .focused($noteFocused)
                .submitLabel(.done)
                .onSubmit(saveLog)
                .padding(12)
                .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ActivityCategory.allCases) { option in
                        Button {
                            category = option
                            saveLog()
                        } label: {
                            Label(option.title, systemImage: option.icon)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(category == option ? Color.green : .white)
                                .background(category == option ? .white : .white.opacity(0.2), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func saveLog() {
        guard let id = engine.loggedSessionID else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        history.update(id: id) {
            $0.note = trimmed
            $0.category = category
        }
    }
}
