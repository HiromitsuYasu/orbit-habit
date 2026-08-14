import Foundation
import SwiftData

@Model
final class CompletionRecord {
    @Attribute(.unique) var recordKey: String
    var localDay: Date
    var completedAt: Date
    var habit: Habit?

    init(habit: Habit, localDay: Date, completedAt: Date = .now, calendar: Calendar = .autoupdatingCurrent) {
        self.recordKey = LocalDay.recordKey(habitID: habit.id, day: localDay, calendar: calendar)
        self.localDay = LocalDay.start(of: localDay, calendar: calendar)
        self.completedAt = completedAt
        self.habit = habit
    }
}
