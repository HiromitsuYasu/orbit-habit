import SwiftData
import SwiftUI

struct HabitEditorView: View {
    private let habit: Habit?
    private let onDeleted: (() -> Void)?

    @State private var draft: HabitDraft
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \Habit.sortIndex) private var habits: [Habit]

    init(habit: Habit? = nil, onDeleted: (() -> Void)? = nil) {
        self.habit = habit
        self.onDeleted = onDeleted
        _draft = State(initialValue: habit.map(HabitDraft.init) ?? HabitDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("習慣名") {
                    TextField("例：読書", text: $draft.name)
                        .textInputAutocapitalization(.sentences)
                }

                Section("アイコン") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(HabitIconCatalog.options, id: \.self) { icon in
                            Button {
                                draft.iconName = icon
                            } label: {
                                HabitIcon(name: icon, color: AppTheme.color(for: draft.accentToken))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                draft.iconName == icon ? AppTheme.accentColor : .clear,
                                                lineWidth: 2
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("テーマカラー") {
                    HStack(spacing: 18) {
                        ForEach(HabitAccentToken.allCases) { token in
                            Button {
                                draft.accentToken = token.rawValue
                            } label: {
                                Circle()
                                    .fill(AppTheme.color(for: token))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Circle().stroke(.white, lineWidth: draft.accentToken == token.rawValue ? 2 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(token.rawValue)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("実行曜日") {
                    WeekdayPicker(mask: $draft.weekdayMask, calendar: environment.calendar)
                }

                Section("通知") {
                    Toggle("通知を有効にする", isOn: $draft.notificationEnabled)
                    if draft.notificationEnabled {
                        DatePicker("時刻", selection: notificationTime, displayedComponents: .hourAndMinute)
                    }
                }

                if habit == nil {
                    Section {
                        Text("習慣は最大10件まで追加できます。")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                } else {
                    Section {
                        Button("この習慣を削除", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(habit == nil ? "習慣を追加" : "習慣を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!draft.isValid)
                }
            }
            .alert("保存できません", isPresented: $errorMessage.isPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("この習慣を削除しますか？", isPresented: $showsDeleteConfirmation) {
                Button("削除", role: .destructive) { deleteHabit() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("習慣と完了記録は元に戻せません。")
            }
        }
    }

    private var notificationTime: Binding<Date> {
        Binding {
            var components = DateComponents()
            components.hour = draft.notificationHour
            components.minute = draft.notificationMinute
            return environment.calendar.date(from: components) ?? environment.now()
        } set: { value in
            let components = environment.calendar.dateComponents([.hour, .minute], from: value)
            draft.notificationHour = components.hour ?? 20
            draft.notificationMinute = components.minute ?? 0
        }
    }

    private func save() {
        let actions = environment.habitActions(modelContext: modelContext)

        Task {
            do {
                if let habit {
                    try await actions.update(habit, with: draft)
                } else {
                    try await actions.create(from: draft, existingCount: habits.count)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteHabit() {
        guard let habit else { return }
        let actions = environment.habitActions(modelContext: modelContext)
        Task {
            do {
                try await actions.delete(habit)
                dismiss()
                onDeleted?()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct WeekdayPicker: View {
    @Binding var mask: Int
    let calendar: Calendar

    private var labels: [String] {
        HabitSchedule.mondayFirstSymbols(from: calendar.veryShortWeekdaySymbols)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let selected = (mask & (1 << index)) != 0
                Button {
                    mask ^= 1 << index
                } label: {
                    Text(label)
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(selected ? AppTheme.accentColor.opacity(0.20) : AppTheme.surfaceElevated)
                        .foregroundStyle(selected ? AppTheme.accentColor : .primary)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(selected ? AppTheme.accentColor : .white.opacity(0.16), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) \(selected ? "選択済み" : "未選択")")
            }
        }
    }
}

#Preview {
    HabitEditorView()
        .modelContainer(PreviewContainer.shared)
        .environment(AppEnvironment.live)
        .preferredColorScheme(.dark)
}
