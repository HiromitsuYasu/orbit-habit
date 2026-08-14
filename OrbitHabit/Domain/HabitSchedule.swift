import Foundation

struct HabitSchedule {
    /// `Calendar.Component.weekday`を月曜始まりの0...6へ変換して判定します。
    static func isScheduled(_ habit: Habit, on day: Date, calendar: Calendar) -> Bool {
        let appleWeekday = calendar.component(.weekday, from: day) // Sun=1 ... Sat=7
        let mondayBasedIndex = (appleWeekday + 5) % 7              // Mon=0 ... Sun=6
        return (habit.weekdayMask & (1 << mondayBasedIndex)) != 0
    }

    static func weekdayLabel(for mask: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let mondayFirstSymbols = Array(symbols.dropFirst()) + [symbols[0]]
        let selected = mondayFirstSymbols.enumerated().compactMap { index, symbol in
            (mask & (1 << index)) != 0 ? symbol : nil
        }
        return selected.joined(separator: locale.language.languageCode?.identifier == "ja" ? "・" : ", ")
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
