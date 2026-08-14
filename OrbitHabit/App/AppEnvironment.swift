import Foundation
import Observation

@Observable
@MainActor
final class AppEnvironment {
    let preferences: AppPreferences
    let notificationScheduler: any NotificationScheduling
    var calendar: Calendar
    var now: @Sendable () -> Date

    init(
        preferences: AppPreferences = AppPreferences(),
        notificationScheduler: some NotificationScheduling = NotificationScheduler(),
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.preferences = preferences
        self.notificationScheduler = notificationScheduler
        self.calendar = calendar
        self.now = now
    }

    static let live = AppEnvironment()
}
