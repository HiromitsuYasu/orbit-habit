import SwiftData
import SwiftUI

struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var environment
    @State private var selectedMonth = Date.now
    @State private var showsEditor = false
    @State private var errorMessage: String?

    private var metrics: HabitMetricsCalculator {
        HabitMetricsCalculator(calendar: environment.calendar)
    }

    private var accent: Color {
        AppTheme.color(for: habit.accentToken)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                identity
                streakCard
                calendarSection
                rateSection
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background)
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") { showsEditor = true }
            }
        }
        .sheet(isPresented: $showsEditor) {
            HabitEditorView(habit: habit)
        }
        .alert("操作を完了できません", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var identity: some View {
        HStack(spacing: 14) {
            HabitIcon(name: habit.iconName, color: accent, size: 62)
            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name)
                    .font(.title2.weight(.bold))
                Text(HabitSchedule.weekdayLabel(for: habit.weekdayMask))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            if habit.notificationEnabled {
                Text(String(format: "%02d:%02d", habit.notificationHour, habit.notificationMinute))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }

    private var streakCard: some View {
        OrbitCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("連続達成")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text("\(metrics.streak(for: habit, endingAt: environment.now())) 日")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                }
                Spacer()
                OrbitProgressRing(
                    progress: min(Double(metrics.streak(for: habit, endingAt: environment.now())) / 30, 1),
                    color: accent
                )
                .frame(width: 100, height: 100)
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedMonth, format: .dateTime.year().month(.wide))
                    .font(.title3.weight(.bold))
                Spacer()
                Button {
                    selectedMonth = environment.calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.left")
                }
                Button {
                    selectedMonth = environment.calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            OrbitCard {
                MonthGrid(
                    habit: habit,
                    month: selectedMonth,
                    accent: accent,
                    calendar: environment.calendar,
                    isCompleted: { day in metrics.isCompleted(habit, on: day) },
                    onTap: toggle
                )
            }
        }
    }

    private var rateSection: some View {
        HStack(spacing: 12) {
            RateCard(title: "直近7日", rate: metrics.completionRate(for: habit, endingAt: environment.now(), days: 7), color: accent)
            RateCard(title: "直近30日", rate: metrics.completionRate(for: habit, endingAt: environment.now(), days: 30), color: accent)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func toggle(_ day: Date) {
        guard HabitSchedule.isScheduled(habit, on: day, calendar: environment.calendar) else { return }
        let actions = environment.habitActions(modelContext: modelContext)
        Task {
            do {
                try await actions.toggleCompletion(for: habit, on: day)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct MonthGrid: View {
    let habit: Habit
    let month: Date
    let accent: Color
    let calendar: Calendar
    let isCompleted: (Date) -> Bool
    let onTap: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        return Array(symbols.dropFirst()) + [symbols[0]]
    }

    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let count = calendar.range(of: .day, in: .month, for: month)?.count
        else {
            return []
        }
        let firstIndex = (calendar.component(.weekday, from: interval.start) + 5) % 7
        let dates = (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
        return Array(repeating: nil, count: firstIndex) + dates
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayCell(for: date)
                } else {
                    Color.clear.frame(height: 30)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let scheduled = HabitSchedule.isScheduled(habit, on: date, calendar: calendar)
        let completed = isCompleted(date)
        Button {
            onTap(date)
        } label: {
            Text(date, format: .dateTime.day())
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .foregroundStyle(scheduled ? .primary : AppTheme.secondaryText.opacity(0.55))
                .background(completed ? accent.opacity(0.20) : .clear)
                .overlay {
                    Circle()
                        .stroke(completed ? accent : (scheduled ? Color.white.opacity(0.24) : .clear), lineWidth: 1.5)
                }
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!scheduled)
        .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
    }
}

private struct RateCard: View {
    let title: LocalizedStringKey
    let rate: Double
    let color: Color

    var body: some View {
        OrbitCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                HStack {
                    Text(rate, format: .percent.precision(.fractionLength(0)))
                        .font(.title2.weight(.bold))
                    Spacer()
                    OrbitProgressRing(progress: rate, color: color, lineWidth: 5)
                        .frame(width: 42, height: 42)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HabitDetailView(habit: PreviewContainer.sampleHabit)
    }
    .modelContainer(PreviewContainer.shared)
    .environment(AppEnvironment.live)
    .preferredColorScheme(.dark)
}
