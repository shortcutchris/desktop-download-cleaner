import Foundation
import UniformTypeIdentifiers

public struct ClassificationEngine: Sendable {
    private let exclusions: [ExclusionRule]

    public init(exclusions: [ExclusionRule] = []) {
        self.exclusions = exclusions
    }

    public func classify(_ item: ScannedItem) -> Classification {
        if let exclusion = exclusions.first(where: { $0.matches(item) }) {
            return Classification(
                category: .unclear,
                confidence: .high,
                reason: "Matches exclusion rule \(exclusion.pattern)",
                isExcluded: true
            )
        }

        if Self.isSensitive(item) {
            return Classification(
                category: .sensitive,
                confidence: .high,
                reason: "Matches a protected credential or database pattern",
                isExcluded: false,
                isSensitive: true
            )
        }

        if item.isHidden {
            return Classification(
                category: .unclear,
                confidence: .high,
                reason: "Hidden files are excluded by the default safety rule",
                isExcluded: true
            )
        }

        let lowercasedName = item.filename.lowercased()
        if Self.isScreenshot(lowercasedName), conforms(item, to: .image) {
            return result(.screenshots, "Image filename matches the system screenshot convention")
        }

        if item.isPackage, ["app", "pkg", "mpkg"].contains(item.pathExtension.lowercased()) {
            return result(.installers, "Package is an application or installer")
        }

        if let type = item.typeIdentifier.flatMap(UTType.init) {
            if type.conforms(to: .diskImage)
                || Self.installerTypeIdentifiers.contains(item.typeIdentifier ?? "") {
                return result(.installers, "Uniform Type Identifier identifies an installer or disk image")
            }
            if type.conforms(to: .archive) {
                return result(.archives, "Uniform Type Identifier identifies an archive")
            }
            if type.conforms(to: .image) { return result(.images, "Uniform Type Identifier identifies an image") }
            if type.conforms(to: .movie) { return result(.video, "Uniform Type Identifier identifies a video") }
            if type.conforms(to: .audio) { return result(.audio, "Uniform Type Identifier identifies audio") }
            if type.conforms(to: .font) { return result(.fonts, "Uniform Type Identifier identifies a font") }
            if type.conforms(to: .sourceCode) {
                return result(.codeAndProjects, "Uniform Type Identifier identifies source code")
            }
            if type.conforms(to: .pdf) || type.conforms(to: .text) || type.conforms(to: .spreadsheet) || type.conforms(to: .presentation) {
                return result(.documents, "Uniform Type Identifier identifies a document")
            }
        }

        let ext = item.pathExtension.lowercased()
        if Self.archiveExtensions.contains(ext) { return result(.archives, "Filename extension identifies an archive", .medium) }
        if Self.installerExtensions.contains(ext) { return result(.installers, "Filename extension identifies an installer", .medium) }
        if Self.projectExtensions.contains(ext) { return result(.codeAndProjects, "Filename extension identifies a code or project file", .medium) }
        if Self.documentExtensions.contains(ext) { return result(.documents, "Filename extension identifies a document", .medium) }

        return Classification(category: .unclear, confidence: .low, reason: "No deterministic rule matched")
    }

    private func conforms(_ item: ScannedItem, to expectedType: UTType) -> Bool {
        item.typeIdentifier.flatMap(UTType.init)?.conforms(to: expectedType) == true
    }

    private func result(
        _ category: ItemCategory,
        _ reason: String,
        _ confidence: ClassificationConfidence = .high
    ) -> Classification {
        Classification(category: category, confidence: confidence, reason: reason)
    }

    private static func isScreenshot(_ filename: String) -> Bool {
        filename.hasPrefix("screenshot ") || filename.hasPrefix("screen shot ") || filename.hasPrefix("bildschirmfoto ")
    }

    private static func isSensitive(_ item: ScannedItem) -> Bool {
        let name = item.filename.lowercased()
        let ext = item.pathExtension.lowercased()
        let exactNames = [".env", "id_rsa", "id_ed25519"]
        if exactNames.contains(name) { return true }
        if name.hasPrefix("credentials.") || name.hasPrefix("id_rsa") || name.hasPrefix("id_ed25519") { return true }
        return ["pem", "key", "p8", "p12", "mobileprovision", "sqlite", "db"].contains(ext)
    }

    private static let archiveExtensions = Set(["zip", "tar", "gz", "bz2", "xz", "7z", "rar"])
    private static let installerTypeIdentifiers = Set(["com.apple.installer-package", "com.apple.installer-package-archive"])
    private static let installerExtensions = Set(["dmg", "pkg", "mpkg"])
    private static let projectExtensions = Set(["swift", "xcodeproj", "xcworkspace", "js", "ts", "py", "rb", "go", "rs", "json", "yaml", "yml"])
    private static let documentExtensions = Set(["pdf", "txt", "rtf", "md", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv"])
}
