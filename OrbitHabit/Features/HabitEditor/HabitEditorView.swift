import SwiftData
import SwiftUI

struct HabitEditorView: View {
    private let habit: Habit?
    @State private var draft: HabitDraft
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var environment
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.sortIndex) private var habits: [Habit]

    private let iconOptions = [
        "book.closed", "figure.run", "character.book.closed", "sun.max", "drop", "leaf", "brain.head.profile", "pencil"
    ]

    init(habit: Habit? = nil) {
        self.habit = habit
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
                        ForEach(iconOptions, id: \.self) { icon in
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
                        ForEach(AppTheme.accentChoices, id: \.self) { token in
                            Button {
                                draft.accentToken = token
                            } label: {
                                Circle()
                                    .fill(AppTheme.color(for: token))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Circle().stroke(.white, lineWidth: draft.accentToken == token ? 2 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(token)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("実行曜日") {
                    WeekdayPicker(mask: $draft.weekdayMask)
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
            .alert("保存できません", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
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

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func save() {
        let service = HabitActionService(
            modelContext: modelContext,
            scheduler: environment.notificationScheduler,
            preferences: environment.preferences,
            calendar: environment.calendar,
            now: environment.now
        )

        Task {
            do {
                if let habit {
                    try await service.update(habit, with: draft)
                } else {
                    try await service.create(from: draft, existingCount: habits.count)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct WeekdayPicker: View {
    @Binding var mask: Int
    private var labels: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return Array(symbols.dropFirst()) + [symbols[0]]
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
