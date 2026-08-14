import Foundation
import SwiftData

@MainActor
enum PreviewContainer {
    static let shared = makeContainer()

    static let sampleHabit = Habit(
        name: "読書",
        iconName: "book.closed",
        accentToken: HabitAccentToken.default.rawValue,
        weekdayMask: 0b1111111,
        sortIndex: 0,
        notificationEnabled: true,
        notificationHour: 21,
        notificationMinute: 0
    )

    private static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(
                for: Habit.self,
                CompletionRecord.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            let habit = sampleHabit
            context.insert(habit)
            context.insert(
                CompletionRecord(
                    habit: habit,
                    localDay: .now,
                    completedAt: .now,
                    calendar: .autoupdatingCurrent
                )
            )
            try context.save()
            return container
        } catch {
            fatalError("Preview SwiftData container could not be created: \(error)")
        }
    }
}
