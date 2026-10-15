import Charts
import SwiftUI

/// Month at a glance: calendar, totals, minutes per day, and what the time went to.
struct OverviewView: View {
    @EnvironmentObject private var history: HistoryStore
    @AppStorage(SettingsKey.dailyGoalMinutes) private var goalMinutes = 30

    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var selectedDay: Date?
    @State private var editing: Session?

    private var calendar: Calendar { .current }

    var body: some View {
        let summary = history.summary(forMonthContaining: month)
        let goal = max(goalMinutes, 1) * 60

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    stats(summary, goal: goal)
                    card {
                        MonthCalendar(month: month, daily: summary.daily, goalSeconds: goal, selected: $selectedDay)
                    }
                    if let selectedDay {
                        dayDetail(selectedDay)
                    }
                    if !summary.sessions.isEmpty {
                        card { dailyChart(summary, goal: goal) }
                        card { categoryBreakdown(summary) }
                        card { topTimers(summary) }
                    } else {
                        ContentUnavailableView("No Sessions This Month", systemImage: "calendar",
                                               description: Text("Time you log with any timer adds up here."))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Overview")
            .sheet(item: $editing) { SessionEditor(session: $0) }
        }
    }

    // MARK: Sections

    private var monthHeader: some View {
        let current = calendar.dateInterval(of: .month, for: .now)!.start
        return HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .disabled(month >= current)
            .accessibilityLabel("Next month")
        }
    }

    private func stats(_ summary: MonthSummary, goal: Int) -> some View {
        let goalDays = summary.daily.values.filter { $0 >= goal }.count
        let average = summary.activeDays > 0 ? summary.totalSeconds / summary.activeDays : 0
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "Total time", value: formatDuration(summary.totalSeconds), icon: "clock.fill", color: .blue)
            StatTile(title: "Sessions", value: "\(summary.sessions.count)", icon: "checkmark.circle.fill", color: .green)
            StatTile(title: "Active days", value: "\(summary.activeDays)", icon: "calendar", color: .purple)
            StatTile(title: "Goal reached", value: goalDays == 1 ? "1 day" : "\(goalDays) days", icon: "target", color: .red)
            StatTile(title: "Best streak", value: summary.longestStreak == 1 ? "1 day" : "\(summary.longestStreak) days",
                     icon: "flame.fill", color: .orange)
            StatTile(title: "Avg per active day", value: formatDuration(average), icon: "chart.bar.fill", color: .teal)
        }
    }

    private func dayDetail(_ day: Date) -> some View {
        let sessions = history.sessions(on: day)
        return card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.headline)
                    Spacer()
                    Text(formatDuration(history.seconds(on: day)))
                        .font(.headline)
                        .monospacedDigit()
                }
                if sessions.isEmpty {
                    Text("Nothing logged.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        Button { editing = session } label: { SessionRow(session: session) }
                            .tint(.primary)
                        if session.id != sessions.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func dailyChart(_ summary: MonthSummary, goal: Int) -> some View {
        let month = calendar.dateInterval(of: .month, for: self.month)!
        return VStack(alignment: .leading, spacing: 12) {
            Text("Minutes per day")
                .font(.headline)
            Chart {
                ForEach(summary.sessions) { session in
                    BarMark(x: .value("Day", calendar.startOfDay(for: session.start), unit: .day),
                            y: .value("Minutes", Double(session.seconds) / 60))
                        .foregroundStyle(by: .value("Category", session.category.title))
                }
                RuleMark(y: .value("Goal", goal / 60))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal").font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartForegroundStyleScale(domain: ActivityCategory.allCases.map(\.title),
                                       range: ActivityCategory.allCases.map(\.color))
            .chartXScale(domain: month.start...month.end)
            .chartLegend(.hidden)
            .frame(height: 180)
        }
    }

    private func categoryBreakdown(_ summary: MonthSummary) -> some View {
        let total = max(summary.totalSeconds, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("What you used it for")
                .font(.headline)
            ForEach(summary.byCategory, id: \.category) { item in
                let fraction = Double(item.seconds) / Double(total)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(item.category.title, systemImage: item.category.icon)
                            .foregroundStyle(item.category.color)
                        Spacer()
                        Text("\(formatDuration(item.seconds)) · \(Int((fraction * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemFill))
                            Capsule().fill(item.category.color)
                                .frame(width: max(6, proxy.size.width * fraction))
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private func topTimers(_ summary: MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Most used")
                .font(.headline)
            ForEach(Array(summary.byTimer.prefix(5).enumerated()), id: \.element.name) { index, item in
                HStack {
                    Text("\(index + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .leading)
                    Text(item.name)
                    Spacer()
                    Text("\(item.count)×  \(formatDuration(item.seconds))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: Helpers

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) {
            month = next
            selectedDay = nil
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

/// Calendar grid shaded by how much was logged each day; full green once the goal is met.
struct MonthCalendar: View {
    let month: Date
    let daily: [Date: Int]
    let goalSeconds: Int
    @Binding var selected: Date?

    private var calendar: Calendar { .current }

    var body: some View {
        let days = calendar.range(of: .day, in: .month, for: month)!.map {
            calendar.date(byAdding: .day, value: $0 - 1, to: month)!
        }
        let leading = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        let cells: [Date?] = Array(repeating: nil, count: leading) + days
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let weekdays = Array(symbols[(calendar.firstWeekday - 1)...] + symbols[..<(calendar.firstWeekday - 1)])
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(weekdays.indices, id: \.self) { i in
                Text(weekdays[i])
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(cells.indices, id: \.self) { i in
                if let day = cells[i] {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 38)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let seconds = daily[day] ?? 0
        let fraction = min(Double(seconds) / Double(goalSeconds), 1)
        let isSelected = selected == day
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > .now

        return Button {
            selected = isSelected ? nil : day
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.subheadline.weight(isToday ? .bold : .regular))
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 38)
                .foregroundStyle(fraction >= 1 ? .white : isFuture ? .secondary : .primary)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(seconds > 0 ? Color.green.opacity(0.25 + 0.75 * fraction) : Color(.tertiarySystemFill))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.primary : isToday ? Color.green : .clear,
                                      lineWidth: isSelected ? 2 : 1.5)
                }
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel("\(day.formatted(date: .long, time: .omitted)), \(seconds > 0 ? formatDuration(seconds) : "nothing logged")")
    }
}
