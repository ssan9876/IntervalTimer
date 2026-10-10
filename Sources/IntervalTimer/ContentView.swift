import IntervalKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var engine: TimerEngine
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var draft: Workout?
    @State private var showSettings = false
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            List {
                if notificationsDenied {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notifications are off", systemImage: "bell.slash.fill")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            Text("You won't get interval alerts on your iPhone or Apple Watch while the app is in the background.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Turn On in Settings") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    openURL(url)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    ForEach($store.workouts) { $workout in
                        NavigationLink {
                            WorkoutEditor(workout: $workout)
                        } label: {
                            WorkoutRow(workout: workout) { engine.start(workout) }
                        }
                    }
                    .onDelete { store.workouts.remove(atOffsets: $0) }
                    .onMove { store.workouts.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            .overlay {
                if store.workouts.isEmpty {
                    ContentUnavailableView("No Workouts", systemImage: "timer",
                                           description: Text("Tap + to set up your first interval workout."))
                }
            }
            .navigationTitle("Intervals")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                    Button { draft = .blank } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $draft) { workout in
                NewWorkoutSheet(workout: workout) { store.workouts.append($0) }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .fullScreenCover(isPresented: Binding(get: { engine.run != nil },
                                              set: { if !$0 { engine.stop() } })) {
            RunnerView()
        }
        .task {
            await Notifier.requestAuthorization()
            notificationsDenied = await Notifier.isDenied()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            engine.resync()
            Task { notificationsDenied = await Notifier.isDenied() }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.name.isEmpty ? "Untitled" : workout.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    ForEach(workout.steps) { step in
                        Capsule()
                            .fill(Palette.color(step.colorIndex))
                            .frame(width: 16, height: 6)
                    }
                }
                Text(workout.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.green, in: Circle())
            }
            .buttonStyle(.borderless)
            .disabled(workout.segments.isEmpty)
        }
        .padding(.vertical, 4)
    }
}

struct NewWorkoutSheet: View {
    @State var workout: Workout
    let onSave: (Workout) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WorkoutEditor(workout: $workout, showsStart: false)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            onSave(workout)
                            dismiss()
                        }
                        .disabled(workout.steps.isEmpty)
                    }
                }
        }
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKey.keepAwake) private var keepAwake = false
    @AppStorage(SettingsKey.audioCues) private var audioCues = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Audio cues", isOn: $audioCues)
                } footer: {
                    Text("Beeps 3-2-1 before each interval ends and chimes when the next one starts. Plays over your music without pausing it.")
                }
                Section {
                    Toggle("Keep screen on while running", isOn: $keepAwake)
                } footer: {
                    Text("Leave this off to get alerts on your Apple Watch. iPhone only passes notifications to the Watch while the phone is locked. The Live Activity keeps the countdown on your Lock Screen, Dynamic Island and Watch Smart Stack.")
                }
                Section {
                    Button("Notification Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                } footer: {
                    Text("Interval alerts are mirrored to a paired Apple Watch automatically. If they don't show up, open the Watch app on your iPhone → Notifications → Intervals and pick “Mirror my iPhone”.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
