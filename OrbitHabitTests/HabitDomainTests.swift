import XCTest
@testable import OrbitHabit

final class HabitDomainTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.firstWeekday = 2
    }

    func testMondayUsesBitZero() {
        let habit = Habit(
            name: "Reading",
            iconName: "book.closed",
            accentToken: "cyan",
            weekdayMask: 1 << 0,
            sortIndex: 0
        )
        let monday = date(year: 2026, month: 8, day: 10)
        let tuesday = date(year: 2026, month: 8, day: 11)

        XCTAssertTrue(HabitSchedule.isScheduled(habit, on: monday, calendar: calendar))
        XCTAssertFalse(HabitSchedule.isScheduled(habit, on: tuesday, calendar: calendar))
    }

    func testCompletionRateExcludesUnscheduledDays() {
        let habit = Habit(
            name: "Reading",
            iconName: "book.closed",
            accentToken: "cyan",
            weekdayMask: (1 << 0) | (1 << 2) | (1 << 4),
            sortIndex: 0,
            createdAt: date(year: 2026, month: 8, day: 3)
        )
        let completedMonday = date(year: 2026, month: 8, day: 3)
        let record = CompletionRecord(habit: habit, localDay: completedMonday, calendar: calendar)
        habit.completionRecords.append(record)

        let metrics = HabitMetricsCalculator(calendar: calendar)
        let rate = metrics.completionRate(
            for: habit,
            endingAt: date(year: 2026, month: 8, day: 9),
            days: 7
        )

        XCTAssertEqual(rate, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testStreakSkipsUnscheduledDays() {
        let habit = Habit(
            name: "Run",
            iconName: "figure.run",
            accentToken: "cyan",
            weekdayMask: (1 << 0) | (1 << 2) | (1 << 4),
            sortIndex: 0,
            createdAt: date(year: 2026, month: 8, day: 3)
        )
        let monday = date(year: 2026, month: 8, day: 3)
        let wednesday = date(year: 2026, month: 8, day: 5)
        let friday = date(year: 2026, month: 8, day: 7)

        for day in [monday, wednesday, friday] {
            habit.completionRecords.append(CompletionRecord(habit: habit, localDay: day, calendar: calendar))
        }

        let metrics = HabitMetricsCalculator(calendar: calendar)
        XCTAssertEqual(metrics.streak(for: habit, endingAt: friday), 3)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}
