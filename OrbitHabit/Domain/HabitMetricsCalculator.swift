import Foundation

struct HabitMetricsCalculator {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func isCompleted(_ habit: Habit, on day: Date) -> Bool {
        let targetDay = LocalDay.start(of: day, calendar: calendar)
        return habit.completionRecords.contains { record in
            LocalDay.start(of: record.localDay, calendar: calendar) == targetDay
        }
    }

    func completionRate(for habit: Habit, endingAt endDate: Date, days: Int) -> Double {
        guard days > 0 else { return 0 }
        let dates = datesEnding(at: endDate, count: days)
        let scheduledDays = dates.filter { HabitSchedule.isScheduled(habit, on: $0, calendar: calendar) }
        guard !scheduledDays.isEmpty else { return 0 }

        let completedCount = scheduledDays.filter { isCompleted(habit, on: $0) }.count
        return Double(completedCount) / Double(scheduledDays.count)
    }

    func overallCompletionRate(for habits: [Habit], endingAt endDate: Date, days: Int) -> Double {
        let scheduled = habits.flatMap { habit in
            datesEnding(at: endDate, count: days)
                .filter { HabitSchedule.isScheduled(habit, on: $0, calendar: calendar) }
                .map { (habit, $0) }
        }
        guard !scheduled.isEmpty else { return 0 }

        let completed = scheduled.filter { habit, day in
            isCompleted(habit, on: day)
        }.count
        return Double(completed) / Double(scheduled.count)
    }

    /// 予定日だけを遡るため、予定がない日は連続記録を切りません。
    func streak(for habit: Habit, endingAt endDate: Date) -> Int {
        var streak = 0
        var cursor = LocalDay.start(of: endDate, calendar: calendar)
        let earliest = habit.createdAt

        while cursor >= LocalDay.start(of: earliest, calendar: calendar) {
            if HabitSchedule.isScheduled(habit, on: cursor, calendar: calendar) {
                guard isCompleted(habit, on: cursor) else { break }
                streak += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func datesEnding(at endDate: Date, count: Int) -> [Date] {
        let end = LocalDay.start(of: endDate, calendar: calendar)
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: end)
        }.reversed()
    }
}
