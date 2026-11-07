import IntervalKit
import SwiftUI

enum AppTab: Hashable {
    case timers, log, overview
}

struct ContentView: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab = ScreenshotMode.initialTab

    var body: some View {
        TabView(selection: $tab) {
            Tab("Timers", systemImage: "timer", value: .timers) {
                TimersView(showOverview: { tab = .overview })
            }
            Tab("Log", systemImage: "list.bullet.rectangle", value: .log) {
                HistoryView()
            }
            Tab("Overview", systemImage: "calendar", value: .overview) {
                OverviewView()
            }
        }
        .fullScreenCover(isPresented: Binding(get: { engine.run != nil },
                                              set: { if !$0 { engine.stop() } })) {
            RunnerView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                engine.resync()
            } else if phase == .background {
                history.save()
            }
        }
        .task {
            ScreenshotMode.prepare(engine: engine)
        }
    }
}

struct TimersView: View {
    let showOverview: () -> Void

    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var engine: TimerEngine
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var draft: Workout?
    @State private var showSettings = false
    @State private var notificationsDenied = false
    @AppStorage(SettingsKey.notificationsBannerDismissed) private var bannerDismissed = false

    var body: some View {
        NavigationStack {
            List {
                if notificationsDenied && !bannerDismissed {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notifications are off", systemImage: "bell.slash.fill")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            Text("You won't get interval alerts on your iPhone or Apple Watch while the app is in the background.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("Turn On in Settings") {
                                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                        openURL(url)
                                    }
                                }
                                Spacer()
                                Button("Not Now") { bannerDismissed = true }
                                    .foregroundStyle(.secondary)
                            }
                            // Otherwise a tap anywhere in the row triggers both buttons.
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button(action: showOverview) {
                        TodayCard()
                    }
                    .buttonStyle(.plain)
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
                } header: {
                    Text("Timers")
                }
            }
            .overlay {
                if store.workouts.isEmpty {
                    ContentUnavailableView("No Timers", systemImage: "timer",
                                           description: Text("Tap + to set up a workout or a timer for a daily task."))
                }
            }
            .navigationTitle("Intervals")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                    Menu {
                        ForEach(Workout.templates, id: \.title) { template in
                            Button { draft = template.workout } label: {
                                Label(template.title, systemImage: template.icon)
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New timer")
                }
            }
            .sheet(item: $draft) { workout in
                NewWorkoutSheet(workout: workout) { store.workouts.append($0) }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .task {
            notificationsDenied = await Notifier.isDenied()
            switch ScreenshotMode.screen {
            case .editor: draft = Workout.samples[2]
            case .settings: showSettings = true
            default: break
            }
        }
        // Also catches the answer to the permission prompt, which makes the scene inactive.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { notificationsDenied = await Notifier.isDenied() }
        }
    }
}

/// Today's time against the daily goal, the streak, and the last 7 days.
struct TodayCard: View {
    @EnvironmentObject private var history: HistoryStore
    @AppStorage(SettingsKey.dailyGoalMinutes) private var goalMinutes = 30

    var body: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let seconds = history.seconds(on: today)
        let goal = max(goalMinutes, 1) * 60
        let streak = history.currentStreak()

        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(.green.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(Double(seconds) / Double(goal), 1))
                    .stroke(.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if seconds >= goal {
                    Image(systemName: "checkmark")
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                } else {
                    Text("\(seconds / 60)")
                        .font(.title3.bold())
                        .monospacedDigit()
                }
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.headline)
                Text("\(formatDuration(seconds)) of \(formatDuration(goal)) goal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(streak == 1 ? "1-day streak" : "\(streak)-day streak", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(streak > 0 ? .orange : .secondary)
            }

            Spacer(minLength: 0)

            WeekBars(goalSeconds: goal)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the monthly overview")
    }
}

struct WeekBars: View {
    let goalSeconds: Int
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = (0..<7).reversed().map { calendar.date(byAdding: .day, value: -$0, to: today)! }

        HStack(alignment: .bottom, spacing: 4) {
            ForEach(days, id: \.self) { day in
                let fraction = min(Double(history.seconds(on: day)) / Double(goalSeconds), 1)
                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule()
                            .fill(fraction >= 1 ? Color.green : Color.green.opacity(0.6))
                            .frame(height: fraction > 0 ? max(4, 36 * fraction) : 0)
                    }
                    .frame(width: 7, height: 36)
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 9, weight: day == today ? .bold : .regular))
                        .foregroundStyle(day == today ? .primary : .secondary)
                }
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: workout.category.icon)
                        .font(.caption)
                        .foregroundStyle(workout.category.color)
                    Text(workout.name.isEmpty ? "Untitled" : workout.name)
                        .font(.headline)
                }
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
            .disabled(!workout.canRun)
            .accessibilityLabel("Start \(workout.name.isEmpty ? "Untitled" : workout.name)")
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
                        .disabled(!workout.canRun)
                    }
                }
        }
    }
}

enum AppLinks {
    static let privacy = URL(string: "https://ssan9876.github.io/intervals-site/privacy/")!
    static let support = URL(string: "https://ssan9876.github.io/intervals-site/support/")!

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKey.keepAwake) private var keepAwake = false
    @AppStorage(SettingsKey.audioCues) private var audioCues = true
    @AppStorage(SettingsKey.defaultSound) private var defaultSound = CueSound.default.id
    @AppStorage(SettingsKey.dailyGoalMinutes) private var goalMinutes = 30
    @EnvironmentObject private var sounds: SoundLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Audio cues", isOn: $audioCues)
                    NavigationLink {
                        SoundPicker(selection: Binding(get: { defaultSound },
                                                       set: { defaultSound = $0 ?? CueSound.default.id }),
                                    allowsDefault: false)
                            .navigationTitle("Default Sound")
                    } label: {
                        LabeledContent("Default sound",
                                       value: sounds.name(for: CueSound(id: defaultSound) ?? .default))
                    }
                    .disabled(!audioCues)
                } footer: {
                    Text("Beeps 3-2-1 before each interval ends and plays the sound when the next one starts, including with your iPhone locked. Plays over your music without pausing it. Each timer can pick its own sound.\n\nWith audio cues off you still get notifications, but the Lock Screen countdown can't move on to the next interval until you open the app.")
                }
                Section {
                    Stepper(value: $goalMinutes, in: 5...600, step: 5) {
                        LabeledContent("Daily goal", value: formatDuration(goalMinutes * 60))
                    }
                } footer: {
                    Text("Time logged across all timers each day. Shown on the Today card and the monthly calendar.")
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
                Section {
                    Link("Privacy Policy", destination: AppLinks.privacy)
                    Link("Help & Support", destination: AppLinks.support)
                    LabeledContent("Version", value: AppLinks.version)
                } header: {
                    Text("About")
                } footer: {
                    Text("Your timers and log stay on this device. Intervals has no account, no ads and no tracking.")
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
