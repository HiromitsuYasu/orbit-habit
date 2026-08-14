import Foundation

struct HabitDraft {
    var name: String = ""
    var iconName: String = HabitIconCatalog.default
    var accentToken: String = HabitAccentToken.default.rawValue
    var weekdayMask: Int = 0
    var notificationEnabled = false
    var notificationHour = 20
    var notificationMinute = 0

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && weekdayMask != 0
    }

    init() {}

    init(habit: Habit) {
        name = habit.name
        iconName = habit.iconName
        accentToken = habit.accentToken
        weekdayMask = habit.weekdayMask
        notificationEnabled = habit.notificationEnabled
        notificationHour = habit.notificationHour
        notificationMinute = habit.notificationMinute
    }
}
