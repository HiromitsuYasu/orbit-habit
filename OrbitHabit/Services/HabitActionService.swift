import Foundation
import SwiftData

@MainActor
struct HabitActionService {
    let modelContext: ModelContext
    let scheduler: any NotificationScheduling
    let preferences: AppPreferences
    let calendar: Calendar
    let now: () -> Date

    func create(from draft: HabitDraft, existingCount: Int) async throws {
        guard existingCount < HabitLimits.maxCount else { throw HabitActionError.maximumHabitCountReached }
        guard draft.isValid else { throw HabitActionError.invalidHabit }

        let habit = Habit(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: draft.iconName,
            accentToken: draft.accentToken,
            weekdayMask: draft.weekdayMask,
            sortIndex: existingCount,
            notificationEnabled: draft.notificationEnabled,
            notificationHour: draft.notificationHour,
            notificationMinute: draft.notificationMinute,
            createdAt: now()
        )
        modelContext.insert(habit)
        try modelContext.save()
        try await resyncNotifications()
    }

    func update(_ habit: Habit, with draft: HabitDraft) async throws {
        guard draft.isValid else { throw HabitActionError.invalidHabit }

        habit.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.iconName = draft.iconName
        habit.accentToken = draft.accentToken
        habit.weekdayMask = draft.weekdayMask
        habit.notificationEnabled = draft.notificationEnabled
        habit.notificationHour = draft.notificationHour
        habit.notificationMinute = draft.notificationMinute
        habit.updatedAt = now()
        try modelContext.save()
        try await resyncNotifications()
    }

    func toggleCompletion(for habit: Habit, on day: Date) async throws {
        let normalizedDay = LocalDay.start(of: day, calendar: calendar)
        let key = LocalDay.recordKey(habitID: habit.id, day: normalizedDay, calendar: calendar)
        let descriptor = FetchDescriptor<CompletionRecord>(predicate: #Predicate { $0.recordKey == key })

        if let record = try modelContext.fetch(descriptor).first {
            modelContext.delete(record)
            try modelContext.save()
            await scheduler.scheduleIfNeeded(
                habit: habit,
                on: normalizedDay,
                notificationsEnabled: preferences.notificationsEnabled,
                locale: preferences.locale,
                calendar: calendar,
                now: now()
            )
        } else {
            let record = CompletionRecord(habit: habit, localDay: normalizedDay, completedAt: now(), calendar: calendar)
            modelContext.insert(record)
            try modelContext.save()
            await scheduler.cancel(habitID: habit.id, on: normalizedDay, calendar: calendar)
        }
    }

    func move(_ habits: [Habit], from source: IndexSet, to destination: Int) throws {
        var reordered = habits
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in reordered.enumerated() {
            habit.sortIndex = index
            habit.updatedAt = now()
        }
        try modelContext.save()
    }

    func delete(_ habit: Habit) async throws {
        await scheduler.cancelAll(for: habit.id)
        modelContext.delete(habit)
        try modelContext.save()
    }

    func deleteAll(habits: [Habit]) async throws {
        await scheduler.cancelAll()
        for habit in habits {
            modelContext.delete(habit)
        }
        try modelContext.save()
    }

    private func resyncNotifications() async throws {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortIndex)])
        let habits = try modelContext.fetch(descriptor)
        await scheduler.resync(
            habits: habits,
            notificationsEnabled: preferences.notificationsEnabled,
            locale: preferences.locale,
            calendar: calendar,
            now: now()
        )
    }
}

enum HabitActionError: LocalizedError {
    case invalidHabit
    case maximumHabitCountReached

    var errorDescription: String? {
        switch self {
        case .invalidHabit:
            String(localized: "習慣名と実行曜日を設定してください。")
        case .maximumHabitCountReached:
            String(localized: "習慣は最大10件までです。")
        }
    }
}
