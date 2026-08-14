import SwiftData
import XCTest
@testable import OrbitHabit

@MainActor
final class HabitActionServiceTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)
    private var container: ModelContainer?
    private var context: ModelContext?
    private var scheduler: FakeNotificationScheduler?
    private var preferences: AppPreferences?
    private var defaults: UserDefaults?
    private var fixedNow = Date()
    private var service: HabitActionService?

    override func setUp() async throws {
        try await super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.firstWeekday = 2
        fixedNow = date(year: 2026, month: 8, day: 14, hour: 12)

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Habit.self,
            CompletionRecord.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let scheduler = FakeNotificationScheduler()

        let suiteName = "OrbitHabit.HabitActionServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
        let preferences = AppPreferences(defaults: defaults ?? .standard)
        let now = fixedNow

        self.container = container
        self.context = context
        self.scheduler = scheduler
        self.defaults = defaults
        self.preferences = preferences
        self.service = HabitActionService(
            modelContext: context,
            scheduler: scheduler,
            preferences: preferences,
            calendar: calendar,
            now: { now }
        )
    }

    override func tearDown() async throws {
        service = nil
        preferences = nil
        defaults = nil
        scheduler = nil
        context = nil
        container = nil
        try await super.tearDown()
    }

    func testDraftValidationRequiresNameAndWeekday() {
        var draft = HabitDraft()
        XCTAssertFalse(draft.isValid)

        draft.name = "  "
        draft.weekdayMask = 1 << 0
        XCTAssertFalse(draft.isValid)

        draft.name = "Reading"
        XCTAssertTrue(draft.isValid)
    }

    func testCreatePersistsHabitAndResyncsNotifications() async throws {
        let service = try XCTUnwrap(service)
        let context = try XCTUnwrap(context)
        let scheduler = try XCTUnwrap(scheduler)

        try await service.create(from: validDraft(name: "Reading"), existingCount: 0)

        let habits = try context.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(habits[0].name, "Reading")
        XCTAssertEqual(habits[0].sortIndex, 0)
        XCTAssertEqual(scheduler.resyncCallCount, 1)
    }

    func testCreateRejectsInvalidDraft() async throws {
        let service = try XCTUnwrap(service)
        let scheduler = try XCTUnwrap(scheduler)
        var draft = HabitDraft()
        draft.name = ""
        draft.weekdayMask = 1 << 0

        do {
            try await service.create(from: draft, existingCount: 0)
            XCTFail("Expected invalidHabit")
        } catch HabitActionError.invalidHabit {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(scheduler.resyncCallCount, 0)
    }

    func testCreateRejectsWhenAtMaximumCount() async throws {
        let service = try XCTUnwrap(service)
        let scheduler = try XCTUnwrap(scheduler)

        do {
            try await service.create(from: validDraft(name: "Overflow"), existingCount: 10)
            XCTFail("Expected maximumHabitCountReached")
        } catch HabitActionError.maximumHabitCountReached {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(scheduler.resyncCallCount, 0)
    }

    func testToggleCompletionInsertsRecordAndCancelsNotification() async throws {
        let service = try XCTUnwrap(service)
        let context = try XCTUnwrap(context)
        let scheduler = try XCTUnwrap(scheduler)
        let habit = try insertHabit(name: "Run")
        let day = date(year: 2026, month: 8, day: 14)

        try await service.toggleCompletion(for: habit, on: day)

        let records = try context.fetch(FetchDescriptor<CompletionRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].habit?.id, habit.id)
        XCTAssertEqual(scheduler.cancelledDays.count, 1)
        XCTAssertEqual(scheduler.cancelledDays[0].habitID, habit.id)
        XCTAssertEqual(
            LocalDay.start(of: scheduler.cancelledDays[0].day, calendar: calendar),
            LocalDay.start(of: day, calendar: calendar)
        )
    }

    func testToggleCompletionRemovesRecordAndReschedules() async throws {
        let service = try XCTUnwrap(service)
        let context = try XCTUnwrap(context)
        let scheduler = try XCTUnwrap(scheduler)
        let habit = try insertHabit(name: "Run")
        let day = date(year: 2026, month: 8, day: 14)
        try await service.toggleCompletion(for: habit, on: day)
        scheduler.reset()

        try await service.toggleCompletion(for: habit, on: day)

        let records = try context.fetch(FetchDescriptor<CompletionRecord>())
        XCTAssertTrue(records.isEmpty)
        XCTAssertEqual(scheduler.scheduleIfNeededCallCount, 1)
        XCTAssertEqual(scheduler.scheduledHabits.last?.id, habit.id)
    }

    func testDeleteCancelsNotificationsForHabit() async throws {
        let service = try XCTUnwrap(service)
        let context = try XCTUnwrap(context)
        let scheduler = try XCTUnwrap(scheduler)
        let habit = try insertHabit(name: "Delete me")
        let habitID = habit.id

        try await service.delete(habit)

        let habits = try context.fetch(FetchDescriptor<Habit>())
        XCTAssertTrue(habits.isEmpty)
        XCTAssertEqual(scheduler.cancelledHabitIDs, [habitID])
    }

    func testDeleteAllCancelsAllNotifications() async throws {
        let service = try XCTUnwrap(service)
        let context = try XCTUnwrap(context)
        let scheduler = try XCTUnwrap(scheduler)
        let first = try insertHabit(name: "One", sortIndex: 0)
        let second = try insertHabit(name: "Two", sortIndex: 1)

        try await service.deleteAll(habits: [first, second])

        let habits = try context.fetch(FetchDescriptor<Habit>())
        XCTAssertTrue(habits.isEmpty)
        XCTAssertEqual(scheduler.cancelAllCallCount, 1)
    }

    func testMoveUpdatesSortIndex() throws {
        let service = try XCTUnwrap(service)
        let first = try insertHabit(name: "A", sortIndex: 0)
        let second = try insertHabit(name: "B", sortIndex: 1)

        try service.move([first, second], from: IndexSet(integer: 0), to: 2)

        XCTAssertEqual(first.sortIndex, 1)
        XCTAssertEqual(second.sortIndex, 0)
    }

    func testEnvironmentFactoryBuildsService() async throws {
        let context = try XCTUnwrap(context)
        let scheduler = try XCTUnwrap(scheduler)
        let preferences = try XCTUnwrap(preferences)
        let now = fixedNow
        let environment = AppEnvironment(
            preferences: preferences,
            notificationScheduler: scheduler,
            calendar: calendar,
            now: { now }
        )
        let actions = environment.habitActions(modelContext: context)

        try await actions.create(from: validDraft(name: "Via factory"), existingCount: 0)

        let habits = try context.fetch(FetchDescriptor<Habit>())
        XCTAssertEqual(habits.count, 1)
        XCTAssertEqual(scheduler.resyncCallCount, 1)
    }

    private func validDraft(name: String) -> HabitDraft {
        var draft = HabitDraft()
        draft.name = name
        draft.iconName = "book.closed"
        draft.accentToken = "cyan"
        draft.weekdayMask = 0b1111111
        draft.notificationEnabled = true
        draft.notificationHour = 20
        draft.notificationMinute = 0
        return draft
    }

    @discardableResult
    private func insertHabit(name: String, sortIndex: Int = 0) throws -> Habit {
        let context = try XCTUnwrap(context)
        let habit = Habit(
            name: name,
            iconName: "figure.run",
            accentToken: "cyan",
            weekdayMask: 0b1111111,
            sortIndex: sortIndex,
            notificationEnabled: true,
            createdAt: fixedNow
        )
        context.insert(habit)
        try context.save()
        return habit
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }
}

@MainActor
private final class FakeNotificationScheduler: NotificationScheduling {
    var resyncCallCount = 0
    var scheduleIfNeededCallCount = 0
    var cancelAllCallCount = 0
    var cancelledHabitIDs: [UUID] = []
    var cancelledDays: [(habitID: UUID, day: Date)] = []
    var scheduledHabits: [Habit] = []

    func requestAuthorization() async -> Bool { true }

    func resync(
        habits: [Habit],
        notificationsEnabled: Bool,
        locale: Locale,
        calendar: Calendar,
        now: Date
    ) async {
        resyncCallCount += 1
    }

    // Protocol surface is fixed at 6 parameters.
    // swiftlint:disable:next function_parameter_count
    func scheduleIfNeeded(
        habit: Habit,
        on day: Date,
        notificationsEnabled: Bool,
        locale: Locale,
        calendar: Calendar,
        now: Date
    ) async {
        scheduleIfNeededCallCount += 1
        scheduledHabits.append(habit)
    }

    func cancel(habitID: UUID, on day: Date, calendar: Calendar) async {
        cancelledDays.append((habitID, day))
    }

    func cancelAll(for habitID: UUID) async {
        cancelledHabitIDs.append(habitID)
    }

    func cancelAll() async {
        cancelAllCallCount += 1
    }

    func reset() {
        resyncCallCount = 0
        scheduleIfNeededCallCount = 0
        cancelAllCallCount = 0
        cancelledHabitIDs = []
        cancelledDays = []
        scheduledHabits = []
    }
}
