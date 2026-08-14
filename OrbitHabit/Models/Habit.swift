import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var accentToken: String
    var weekdayMask: Int
    var sortIndex: Int

    var notificationEnabled: Bool
    var notificationHour: Int
    var notificationMinute: Int

    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.habit)
    var completionRecords: [CompletionRecord] = []

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        accentToken: String,
        weekdayMask: Int,
        sortIndex: Int,
        notificationEnabled: Bool = false,
        notificationHour: Int = 20,
        notificationMinute: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.accentToken = accentToken
        self.weekdayMask = weekdayMask
        self.sortIndex = sortIndex
        self.notificationEnabled = notificationEnabled
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
