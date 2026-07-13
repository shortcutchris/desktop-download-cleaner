import Foundation

struct AppChangelogManifest: Decodable {
    let releases: [AppRelease]

    static let bundled: AppChangelogManifest = {
        guard let url = Bundle.main.url(forResource: "AppChangelog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(AppChangelogManifest.self, from: data) else {
            return AppChangelogManifest(releases: [])
        }
        return manifest
    }()

    var latest: AppRelease? { releases.first }
}

struct AppRelease: Decodable, Identifiable {
    let version: String
    let build: String
    let date: String
    let summaryKey: String
    let sections: [AppReleaseSection]

    var id: String { version }
}

struct AppReleaseSection: Decodable, Identifiable {
    let kind: AppReleaseKind
    let itemKeys: [String]

    var id: AppReleaseKind { kind }
}

enum AppReleaseKind: String, Decodable {
    case added
    case improved
    case fixed
    case security

    var titleKey: String {
        switch self {
        case .added: "New"
        case .improved: "Improved"
        case .fixed: "Fixed"
        case .security: "Security"
        }
    }

    var iconName: String {
        switch self {
        case .added: "plus.circle.fill"
        case .improved: "arrow.up.circle.fill"
        case .fixed: "wrench.and.screwdriver.fill"
        case .security: "lock.shield.fill"
        }
    }
}

enum AppBuildInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Development"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "—"
    }
}
