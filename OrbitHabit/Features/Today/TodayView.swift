import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortIndex) private var habits: [Habit]

    @State private var showsEditor = false
    @State private var showsLimitAlert = false
    @State private var errorMessage: String?

    private var metrics: HabitMetricsCalculator {
        HabitMetricsCalculator(calendar: environment.calendar)
    }

    private var todayHabits: [Habit] {
        habits.filter { HabitSchedule.isScheduled($0, on: environment.now(), calendar: environment.calendar) }
    }

    private var completedCount: Int {
        todayHabits.filter { metrics.isCompleted($0, on: environment.now()) }.count
    }

    private var progress: Double {
        guard !todayHabits.isEmpty else { return 0 }
        return Double(completedCount) / Double(todayHabits.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    progressCard
                    habitSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if habits.count >= 10 {
                            showsLimitAlert = true
                        } else {
                            showsEditor = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("習慣を追加")
                }
            }
            .sheet(isPresented: $showsEditor) {
                HabitEditorView()
            }
            .alert("習慣は最大10件までです。", isPresented: $showsLimitAlert) {
                Button("OK", role: .cancel) {}
            }
            .alert("操作を完了できません", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await syncNotifications() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await syncNotifications() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(environment.now(), format: .dateTime.month().day().weekday(.wide))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Text("今日")
                .font(.system(size: 44, weight: .bold, design: .rounded))
        }
        .padding(.top, 12)
    }

    private var progressCard: some View {
        OrbitCard {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日の進捗")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(todayHabits.isEmpty ? "予定なし" : "\(completedCount) / \(todayHabits.count) 完了")
                        .font(.title2.weight(.bold))
                }
                Spacer()
                OrbitProgressRing(progress: progress, color: AppTheme.accentColor)
                    .frame(width: 88, height: 88)
            }
        }
    }

    @ViewBuilder
    private var habitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日の習慣")
                .font(.title3.weight(.bold))

            if todayHabits.isEmpty {
                OrbitCard {
                    ContentUnavailableView(
                        "今日は予定がありません",
                        systemImage: "moon.stars",
                        description: Text("右上の追加ボタンから習慣を作成できます。")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
            } else {
                ForEach(todayHabits) { habit in
                    TodayHabitRow(
                        habit: habit,
                        isCompleted: metrics.isCompleted(habit, on: environment.now()),
                        onToggle: { toggle(habit) }
                    )
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func toggle(_ habit: Habit) {
        let actions = environment.habitActions(modelContext: modelContext)
        Task {
            do {
                try await actions.toggleCompletion(for: habit, on: environment.now())
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func syncNotifications() async {
        await environment.notificationScheduler.resync(
            habits: habits,
            notificationsEnabled: environment.preferences.notificationsEnabled,
            locale: environment.preferences.locale,
            calendar: environment.calendar,
            now: environment.now()
        )
    }
}

private struct TodayHabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        OrbitCard {
            HStack(spacing: 14) {
                NavigationLink {
                    HabitDetailView(habit: habit)
                } label: {
                    HStack(spacing: 14) {
                        HabitIcon(name: habit.iconName, color: AppTheme.color(for: habit.accentToken))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(habit.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if habit.notificationEnabled {
                                Text(String(format: "%02d:%02d", habit.notificationHour, habit.notificationMinute))
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                Button(action: onToggle) {
                    Image(systemName: isCompleted ? "checkmark" : "circle")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(isCompleted ? AppTheme.color(for: habit.accentToken) : AppTheme.secondaryText)
                        .frame(width: 44, height: 44)
                        .background(isCompleted ? AppTheme.color(for: habit.accentToken).opacity(0.12) : .clear)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(habit.name)を\(isCompleted ? "未完了に戻す" : "完了にする")")
            }
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewContainer.shared)
        .environment(AppEnvironment.live)
        .preferredColorScheme(.dark)
}
