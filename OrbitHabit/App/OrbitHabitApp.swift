import SwiftData
import SwiftUI

@main
struct OrbitHabitApp: App {
    @State private var environment = AppEnvironment.live

    var body: some Scene {
        WindowGroup {
            OrbitHabitRootView()
                .environment(environment)
                .environment(\.locale, environment.preferences.locale)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Habit.self, CompletionRecord.self])
    }
}
