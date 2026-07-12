import Foundation

public struct SourceFolder: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var displayName: String
    public var scanDepth: Int
    public var isEnabled: Bool
    public var kind: SourceFolderKind

    public init(
        id: UUID = UUID(),
        displayName: String,
        scanDepth: Int = 0,
        isEnabled: Bool = true,
        kind: SourceFolderKind = .source
    ) {
        self.id = id
        self.displayName = displayName
        self.scanDepth = max(0, scanDepth)
        self.isEnabled = isEnabled
        self.kind = kind
    }
}

public enum SourceFolderKind: String, Codable, Sendable {
    case source
    case reviewRoot
}

public struct ScannedItem: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let sourceID: UUID
    public let relativePath: String
    public let filename: String
    public let pathExtension: String
    public let typeIdentifier: String?
    public let size: Int64
    public let creationDate: Date?
    public let modificationDate: Date?
    public let identity: String
    public let isPackage: Bool
    public let isAlias: Bool
    public let isSymbolicLink: Bool
    public let isHidden: Bool

    public init(
        id: UUID = UUID(),
        sourceID: UUID,
        relativePath: String,
        filename: String,
        pathExtension: String,
        typeIdentifier: String? = nil,
        size: Int64 = 0,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        identity: String,
        isPackage: Bool = false,
        isAlias: Bool = false,
        isSymbolicLink: Bool = false,
        isHidden: Bool = false
    ) {
        self.id = id
        self.sourceID = sourceID
        self.relativePath = relativePath
        self.filename = filename
        self.pathExtension = pathExtension
        self.typeIdentifier = typeIdentifier
        self.size = size
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.identity = identity
        self.isPackage = isPackage
        self.isAlias = isAlias
        self.isSymbolicLink = isSymbolicLink
        self.isHidden = isHidden
    }

    public var basename: String {
        guard !pathExtension.isEmpty else { return filename }
        let suffix = ".\(pathExtension)"
        guard filename.lowercased().hasSuffix(suffix.lowercased()) else { return filename }
        return String(filename.dropLast(suffix.count))
    }
}

public enum ItemCategory: String, CaseIterable, Codable, Sendable {
    case documents
    case screenshots
    case images
    case video
    case audio
    case installers
    case archives
    case codeAndProjects
    case fonts
    case sensitive
    case duplicates
    case unclear

    public var folderName: String {
        switch self {
        case .documents: "Documents"
        case .screenshots: "Screenshots"
        case .images: "Images"
        case .video: "Video"
        case .audio: "Audio"
        case .installers: "Installers"
        case .archives: "Archives"
        case .codeAndProjects: "Project Files"
        case .fonts: "Fonts"
        case .sensitive: "Sensitive"
        case .duplicates: "Duplicates"
        case .unclear: "Unclear"
        }
    }
}

public enum ClassificationConfidence: String, Codable, Sendable {
    case high
    case medium
    case low
}

public struct Classification: Codable, Equatable, Sendable {
    public let category: ItemCategory
    public let confidence: ClassificationConfidence
    public let reason: String
    public let isExcluded: Bool
    public let isSensitive: Bool

    public init(
        category: ItemCategory,
        confidence: ClassificationConfidence,
        reason: String,
        isExcluded: Bool = false,
        isSensitive: Bool = false
    ) {
        self.category = category
        self.confidence = confidence
        self.reason = reason
        self.isExcluded = isExcluded
        self.isSensitive = isSensitive
    }
}

public enum ApprovalState: String, Codable, Sendable {
    case pending
    case approved
    case rejected
}

public struct PlanItem: Codable, Identifiable, Sendable {
    public let id: UUID
    public let scannedItem: ScannedItem
    public var classification: Classification
    public var proposedFilename: String
    public var relativeDestination: String
    public var hadCollision: Bool
    public var approvalState: ApprovalState

    public init(
        id: UUID = UUID(),
        scannedItem: ScannedItem,
        classification: Classification,
        proposedFilename: String,
        relativeDestination: String,
        hadCollision: Bool,
        approvalState: ApprovalState = .pending
    ) {
        self.id = id
        self.scannedItem = scannedItem
        self.classification = classification
        self.proposedFilename = proposedFilename
        self.relativeDestination = relativeDestination
        self.hadCollision = hadCollision
        self.approvalState = approvalState
    }
}

public struct CleanupPlan: Codable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let sessionDirectoryName: String
    public var items: [PlanItem]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sessionDirectoryName: String,
        items: [PlanItem]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sessionDirectoryName = sessionDirectoryName
        self.items = items
    }
}
