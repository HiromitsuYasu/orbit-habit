import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppPreferences {
    private enum Key {
        static let language = "app.language"
        static let didCompleteOnboarding = "app.didCompleteOnboarding"
        static let notificationsEnabled = "app.notificationsEnabled"
    }

    private let defaults: UserDefaults

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    var didCompleteOnboarding: Bool {
        didSet { defaults.set(didCompleteOnboarding, forKey: Key.didCompleteOnboarding) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled) }
    }

    var locale: Locale {
        language.locale
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.language = AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "system") ?? .system
        self.didCompleteOnboarding = defaults.bool(forKey: Key.didCompleteOnboarding)
        self.notificationsEnabled = defaults.object(forKey: Key.notificationsEnabled) as? Bool ?? true
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case japanese = "ja"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .japanese:
            Locale(identifier: "ja")
        case .english:
            Locale(identifier: "en")
        }
    }

    var displayKey: LocalizedStringKey {
        switch self {
        case .system: "端末の設定"
        case .japanese: "日本語"
        case .english: "英語"
        }
    }
}
