import Foundation

enum HabitLimits {
    static let maxCount = 10
}

enum HabitAccentToken: String, CaseIterable, Identifiable {
    case cyan
    case violet
    case lime
    case amber
    case magenta

    var id: String { rawValue }

    static let `default` = HabitAccentToken.cyan
}

enum HabitIconCatalog {
    static let options = [
        "book.closed",
        "figure.run",
        "character.book.closed",
        "sun.max",
        "drop",
        "leaf",
        "brain.head.profile",
        "pencil"
    ]

    static let `default` = options[0]
}
