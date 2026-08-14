import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AppEnvironment {
    let preferences: AppPreferences
    let notificationScheduler: any NotificationScheduling
    var calendar: Calendar
    var now: @Sendable () -> Date

    init(
        preferences: AppPreferences,
        notificationScheduler: some NotificationScheduling,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.preferences = preferences
        self.notificationScheduler = notificationScheduler
        self.calendar = calendar
        self.now = now
    }

    func habitActions(modelContext: ModelContext) -> HabitActionService {
        HabitActionService(
            modelContext: modelContext,
            scheduler: notificationScheduler,
            preferences: preferences,
            calendar: calendar,
            now: now
        )
    }

    static let live = AppEnvironment(
        preferences: AppPreferences(),
        notificationScheduler: NotificationScheduler()
    )
}
