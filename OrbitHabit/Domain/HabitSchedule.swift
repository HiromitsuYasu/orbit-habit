import Foundation

struct HabitSchedule {
    /// `Calendar.Component.weekday`を月曜始まりの0...6へ変換します。
    static func mondayBasedIndex(for day: Date, calendar: Calendar) -> Int {
        let appleWeekday = calendar.component(.weekday, from: day) // Sun=1 ... Sat=7
        return (appleWeekday + 5) % 7 // Mon=0 ... Sun=6
    }

    static func mondayFirstSymbols(from symbols: [String]) -> [String] {
        guard !symbols.isEmpty else { return [] }
        return Array(symbols.dropFirst()) + [symbols[0]]
    }

    static func isScheduled(_ habit: Habit, on day: Date, calendar: Calendar) -> Bool {
        let index = mondayBasedIndex(for: day, calendar: calendar)
        return (habit.weekdayMask & (1 << index)) != 0
    }

    static func weekdayLabel(
        for mask: Int,
        calendar: Calendar,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let symbols = mondayFirstSymbols(from: calendar.shortWeekdaySymbols)
        let selected = symbols.enumerated().compactMap { index, symbol in
            (mask & (1 << index)) != 0 ? symbol : nil
        }
        let separator = locale.language.languageCode?.identifier == "ja" ? "・" : ", "
        return selected.joined(separator: separator)
    }
}

enum LocalDay {
    static func start(of date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    static func recordKey(habitID: UUID, day: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(habitID.uuidString)|\(formatter.string(from: start(of: day, calendar: calendar)))"
    }
}
