import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case german = "de"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .english, .german:
            Locale(identifier: rawValue)
        }
    }

    var aiLanguageName: String {
        switch self {
        case .system:
            Locale.autoupdatingCurrent.language.languageCode?.identifier == "de" ? "German" : "English"
        case .english:
            "English"
        case .german:
            "German"
        }
    }

    var displayNameKey: String {
        switch self {
        case .system: "System Default"
        case .english: "English"
        case .german: "German"
        }
    }
}

enum L10n {
    static func string(
        _ key: String,
        language: AppLanguage,
        arguments: [CVarArg] = []
    ) -> String {
        let format = bundle(for: language).localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: language.locale, arguments: arguments)
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        guard language != .system,
              let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
