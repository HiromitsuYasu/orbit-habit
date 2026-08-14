import Foundation
import UserNotifications

@MainActor
protocol NotificationScheduling {
    func requestAuthorization() async -> Bool
    func resync(
        habits: [Habit],
        notificationsEnabled: Bool,
        locale: Locale,
        calendar: Calendar,
        now: Date
    ) async
    func scheduleIfNeeded(
        habit: Habit,
        on day: Date,
        notificationsEnabled: Bool,
        locale: Locale,
        calendar: Calendar,
        now: Date
    ) async
    func cancel(habitID: UUID, on day: Date, calendar: Calendar) async
    func cancelAll(for habitID: UUID) async
    func cancelAll() async
}

@MainActor
final class NotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter
    private let planningHorizonDays = 6

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func resync(
        habits: [Habit],
        notificationsEnabled: Bool,
        locale: Locale,
        calendar: Calendar,
        now: Date
    ) async {
        let pending = await center.pendingNotificationRequests()
        let appRequestIDs = pending.map(\.identifier).filter { $0.hasPrefix("habit.") }
        center.removePendingNotificationRequests(withIdentifiers: appRequestIDs)

        guard notificationsEnabled else { return }
        let activeHabits = habits.filter { !$0.isArchived && $0.notificationEnabled }
        let start = LocalDay.start(of: now, calendar: calendar)

        for offset in 0..<planningHorizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            for habit in activeHabits {
                await scheduleIfNeeded(
                    habit: habit,
                    on: day,
                    notificationsEnabled: notificationsEnabled,
                    locale: locale,
                    calendar: calendar,
                    now: now
                )
            }
        }
    }

    func scheduleIfNeeded(
        habit: Habit,
        on day: Date,
        notificationsEnabled: Bool,
        locale: Locale,
        calendar: Calendar,
        now: Date
    ) async {
        guard notificationsEnabled,
              habit.notificationEnabled,
              !habit.isArchived,
              HabitSchedule.isScheduled(habit, on: day, calendar: calendar),
              !HabitMetricsCalculator(calendar: calendar).isCompleted(habit, on: day),
              let deliveryDate = calendar.date(
                bySettingHour: habit.notificationHour,
                minute: habit.notificationMinute,
                second: 0,
                of: day
              ),
              deliveryDate > now
        else {
            return
        }

        let content = UNMutableNotificationContent()
        let isJapanese = locale.language.languageCode?.identifier == "ja"
        content.title = isJapanese ? "\(habit.name)の時間です" : "Time for \(habit.name)"
        content.body = isJapanese ? "今日の習慣を完了しましょう。" : "Complete today's habit."
        content.sound = .default
        content.userInfo = ["habitID": habit.id.uuidString]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: deliveryDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(for: habit.id, on: day, calendar: calendar),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            // 通知登録の失敗は記録操作そのものを失敗させません。
        }
    }

    func cancel(habitID: UUID, on day: Date, calendar: Calendar) async {
        center.removePendingNotificationRequests(
            withIdentifiers: [identifier(for: habitID, on: day, calendar: calendar)]
        )
    }

    func cancelAll(for habitID: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let prefix = "habit.\(habitID.uuidString)."
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix("habit.") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func identifier(for habitID: UUID, on day: Date, calendar: Calendar) -> String {
        "habit.\(habitID.uuidString).\(LocalDay.recordKey(habitID: habitID, day: day, calendar: calendar))"
    }
}
