import SwiftUI

/// Day-by-day log of every session and what it was used for.
struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    @State private var editing: Session?

    var body: some View {
        NavigationStack {
            List {
                ForEach(history.days, id: \.self) { day in
                    let sessions = history.sessions(on: day)
                    Section {
                        ForEach(sessions) { session in
                            Button { editing = session } label: {
                                SessionRow(session: session)
                            }
                            .tint(.primary)
                        }
                        .onDelete { offsets in
                            offsets.map { sessions[$0].id }.forEach { history.delete(id: $0) }
                        }
                    } header: {
                        HStack {
                            Text(dayTitle(day))
                            Spacer()
                            Text(formatDuration(history.seconds(on: day)))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .overlay {
                if history.sessions.isEmpty {
                    ContentUnavailableView(
                        "Nothing Logged Yet", systemImage: "list.bullet.rectangle",
                        description: Text("Finished timers show up here with a note about what you used them for. Tap + to log something by hand."))
                }
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = .manual() } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Log a session")
                }
            }
            .sheet(item: $editing) { session in
                SessionEditor(session: session)
            }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.category.icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(session.category.color, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(session.workoutName.isEmpty ? session.category.title : session.workoutName)
                    .font(.headline)
                if !session.note.isEmpty {
                    Text(session.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text(session.start.formatted(date: .omitted, time: .shortened))
                    if !session.completed {
                        Text("Ended early")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatDuration(session.seconds))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

/// Edits a logged session, or adds one by hand.
struct SessionEditor: View {
    @State var session: Session
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    private var isNew: Bool { history.session(id: session.id) == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("What was it for?") {
                    TextField("Note", text: $session.note, axis: .vertical)
                        .lineLimit(2...5)
                    Picker("Category", selection: $session.category) {
                        ForEach(ActivityCategory.allCases) { category in
                            Label(category.title, systemImage: category.icon).tag(category)
                        }
                    }
                }

                Section {
                    TextField("Name (optional)", text: $session.workoutName)
                    DatePicker("Started", selection: $session.start, in: ...Date.now)
                    HoursMinutesPicker(seconds: $session.seconds)
                } header: {
                    Text("Time")
                } footer: {
                    if !session.completed {
                        Text("This run was ended before its last interval.")
                    }
                }

                if !isNew {
                    Section {
                        Button("Delete Session", role: .destructive) {
                            history.delete(id: session.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Log Session" : "Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") {
                        session.note = session.note.trimmingCharacters(in: .whitespacesAndNewlines)
                        session.end = session.start.addingTimeInterval(TimeInterval(session.seconds))
                        history.upsert(session)
                        dismiss()
                    }
                    .disabled(session.seconds <= 0)
                }
            }
        }
    }
}

struct HoursMinutesPicker: View {
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: 0) {
            Picker("Hours", selection: Binding(
                get: { seconds / 3600 },
                set: { seconds = $0 * 3600 + (seconds % 3600) / 60 * 60 }
            )) {
                ForEach(0..<13, id: \.self) { Text("\($0) hr").tag($0) }
            }
            Picker("Minutes", selection: Binding(
                get: { (seconds % 3600) / 60 },
                set: { seconds = (seconds / 3600) * 3600 + $0 * 60 }
            )) {
                ForEach(0..<60, id: \.self) { Text("\($0) min").tag($0) }
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 130)
    }
}
