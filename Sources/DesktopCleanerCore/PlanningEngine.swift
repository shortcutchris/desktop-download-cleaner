import Foundation

public struct PlanningEngine: Sendable {
    private let sanitizer: FilenameSanitizer

    public init(sanitizer: FilenameSanitizer = FilenameSanitizer()) {
        self.sanitizer = sanitizer
    }

    public func makePlan(
        items: [ScannedItem],
        classifications: [UUID: Classification],
        suggestedBasenames: [UUID: String] = [:],
        sessionDirectoryName: String,
        existingRelativeDestinations: Set<String> = []
    ) -> CleanupPlan {
        let safeSessionName = sanitizer.normalizedBasename(sessionDirectoryName)
        var occupied = Set(existingRelativeDestinations.map(Self.collisionKey))
        var planItems: [PlanItem] = []

        for item in items.sorted(by: Self.stableItemOrder) {
            guard let classification = classifications[item.id], !classification.isExcluded else { continue }

            let normalizedFilename = suggestedBasenames[item.id].map {
                sanitizer.filename(basename: $0, pathExtension: item.pathExtension)
            } ?? sanitizer.suggestedFilename(for: item)
            var proposedFilename = normalizedFilename
            var ordinal = 2
            var relativeDestination = Self.relativeDestination(
                session: safeSessionName,
                category: classification.category,
                filename: proposedFilename
            )

            while occupied.contains(Self.collisionKey(relativeDestination)) {
                proposedFilename = sanitizer.collisionFilename(original: normalizedFilename, ordinal: ordinal)
                ordinal += 1
                relativeDestination = Self.relativeDestination(
                    session: safeSessionName,
                    category: classification.category,
                    filename: proposedFilename
                )
            }

            occupied.insert(Self.collisionKey(relativeDestination))
            planItems.append(PlanItem(
                scannedItem: item,
                classification: classification,
                proposedFilename: proposedFilename,
                relativeDestination: relativeDestination,
                hadCollision: proposedFilename != normalizedFilename
            ))
        }

        return CleanupPlan(sessionDirectoryName: safeSessionName, items: planItems)
    }

    private static func relativeDestination(
        session: String,
        category: ItemCategory,
        filename: String
    ) -> String {
        [session, category.folderName, filename].joined(separator: "/")
    }

    private static func collisionKey(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping.lowercased()
    }

    private static func stableItemOrder(_ lhs: ScannedItem, _ rhs: ScannedItem) -> Bool {
        if lhs.relativePath == rhs.relativePath { return lhs.id.uuidString < rhs.id.uuidString }
        return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
    }
}
