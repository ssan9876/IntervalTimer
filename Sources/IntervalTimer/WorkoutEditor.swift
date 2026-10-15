import IntervalKit
import SwiftUI

struct WorkoutEditor: View {
    @Binding var workout: Workout
    var showsStart = true
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var sounds: SoundLibrary

    var body: some View {
        Form {
            Section("Name") {
                TextField("Workout name", text: $workout.name)
            }

            Section {
                Picker("Used for", selection: $workout.category) {
                    ForEach(ActivityCategory.allCases) { category in
                        Label(category.title, systemImage: category.icon).tag(category)
                    }
                }
                NavigationLink {
                    SoundPicker(selection: $workout.sound, allowsDefault: true)
                        .navigationTitle("Sound")
                } label: {
                    LabeledContent("Sound", value: workout.sound == nil
                                   ? "Default" : sounds.name(for: workout.cueSound))
                }
            } footer: {
                Text("Runs are logged under this category. You can add a note about each one when it finishes.")
            }

            Section {
                Stepper(value: $workout.rounds, in: 1...99) {
                    LabeledContent("Rounds", value: "\(workout.rounds)")
                }
                Stepper(value: $workout.prepSeconds, in: 0...60, step: 5) {
                    LabeledContent("Get ready", value: workout.prepSeconds == 0 ? "Off" : "\(workout.prepSeconds)s")
                }
            } footer: {
                Text("Total time: \(formatTime(workout.totalSeconds))")
            }

            Section {
                ForEach($workout.steps) { $step in
                    NavigationLink {
                        StepEditor(step: $step)
                    } label: {
                        StepRow(step: step)
                    }
                }
                .onDelete { workout.steps.remove(atOffsets: $0) }
                .onMove { workout.steps.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    addStep()
                } label: {
                    Label("Add Interval", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Intervals (each round)")
            } footer: {
                Text("Each interval starts automatically when the previous one ends, with a notification on your iPhone and Apple Watch. Swipe to delete, hold and drag to reorder.")
            }
        }
        .navigationTitle(workout.name.isEmpty ? "Workout" : workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsStart {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        engine.start(workout)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(workout.segments.isEmpty)
                }
            }
        }
    }

    private func addStep() {
        // Alternate work/rest-style naming so quick setups need fewer taps.
        let isRest = workout.steps.last.map { $0.name.lowercased().contains("work") } ?? false
        let step = isRest
            ? IntervalStep(name: "Rest", seconds: 15, colorIndex: 0)
            : IntervalStep(name: "Work", seconds: 30, colorIndex: 1)
        workout.steps.append(step)
    }
}

struct StepRow: View {
    let step: IntervalStep

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Palette.color(step.colorIndex))
                .frame(width: 14, height: 14)
            Text(step.name.isEmpty ? "Interval" : step.name)
            Spacer()
            Text(formatTime(step.seconds))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

struct StepEditor: View {
    @Binding var step: IntervalStep

    private let presets = [10, 15, 20, 30, 45, 60, 90, 120, 300]

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Work, Rest, Sprint", text: $step.name)
            }

            Section("Duration") {
                DurationPicker(seconds: $step.seconds)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { value in
                            Button(value < 60 ? "\(value)s" : formatTime(value)) {
                                step.seconds = value
                            }
                            .buttonStyle(.bordered)
                            .tint(step.seconds == value ? .accentColor : .secondary)
                        }
                    }
                }
            }

            Section("Color") {
                HStack {
                    ForEach(Palette.colors.indices, id: \.self) { index in
                        Circle()
                            .fill(Palette.colors[index])
                            .frame(width: 30, height: 30)
                            .overlay {
                                if step.colorIndex == index {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture { step.colorIndex = index }
                        if index < Palette.colors.count - 1 { Spacer(minLength: 0) }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(step.name.isEmpty ? "Interval" : step.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DurationPicker: View {
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: 0) {
            Picker("Minutes", selection: Binding(
                get: { seconds / 60 },
                set: { seconds = max(1, $0 * 60 + seconds % 60) }
            )) {
                ForEach(0..<60, id: \.self) { Text("\($0) min").tag($0) }
            }
            Picker("Seconds", selection: Binding(
                get: { seconds % 60 },
                set: { seconds = max(1, (seconds / 60) * 60 + $0) }
            )) {
                ForEach(0..<60, id: \.self) { Text("\($0) sec").tag($0) }
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 150)
    }
}
