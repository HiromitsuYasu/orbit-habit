import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var environment
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortIndex) private var habits: [Habit]

    @State private var showsDeleteConfirmation = false
    @State private var deleteError: String?

    var body: some View {
        @Bindable var preferences = environment.preferences

        NavigationStack {
            Form {
                Section("表示") {
                    Picker("言語", selection: $preferences.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayKey).tag(language)
                        }
                    }
                    .onChange(of: preferences.language) { _, _ in
                        Task { await syncNotifications() }
                    }
                }

                Section("通知") {
                    Toggle("通知をまとめて有効", isOn: $preferences.notificationsEnabled)
                        .onChange(of: preferences.notificationsEnabled) { _, _ in
                            Task { await syncNotifications() }
                        }
                    Text("習慣ごとの通知は編集画面で設定できます。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Section("習慣を管理") {
                    NavigationLink("習慣を並び替える") {
                        HabitOrderView()
                    }
                }

                Section("データ") {
                    Button("すべてのデータを削除", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                }

                Section {
                    Text("Orbit Habit v1.0")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(AppTheme.secondaryText)
                        .font(.footnote)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("設定")
            .alert("すべてのデータを削除しますか？", isPresented: $showsDeleteConfirmation) {
                Button("削除", role: .destructive) { deleteAll() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("習慣と完了記録は元に戻せません。")
            }
            .alert("削除できません", isPresented: deleteErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
    }

    private func syncNotifications() async {
        await environment.notificationScheduler.resync(
            habits: habits,
            notificationsEnabled: environment.preferences.notificationsEnabled,
            locale: environment.preferences.locale,
            calendar: environment.calendar,
            now: environment.now()
        )
    }

    private func deleteAll() {
        let service = HabitActionService(
            modelContext: modelContext,
            scheduler: environment.notificationScheduler,
            preferences: environment.preferences,
            calendar: environment.calendar,
            now: environment.now
        )
        Task {
            do {
                try await service.deleteAll(habits: habits)
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }
}

private struct HabitOrderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var environment
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortIndex) private var habits: [Habit]
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(habits) { habit in
                Label(habit.name, systemImage: habit.iconName)
            }
            .onMove(perform: move)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("習慣を並び替える")
        .toolbar { EditButton() }
        .alert("並び替えできません", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func move(from source: IndexSet, to destination: Int) {
        let service = HabitActionService(
            modelContext: modelContext,
            scheduler: environment.notificationScheduler,
            preferences: environment.preferences,
            calendar: environment.calendar,
            now: environment.now
        )
        do {
            try service.move(habits, from: source, to: destination)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewContainer.shared)
        .environment(AppEnvironment.live)
        .preferredColorScheme(.dark)
}
