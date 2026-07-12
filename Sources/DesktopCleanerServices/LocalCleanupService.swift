import DesktopCleanerCore
import Foundation

public struct LocalCleanupService: Sendable {
    private let scanner: Scanner
    private let classifier: ClassificationEngine
    private let planner: PlanningEngine
    private let duplicateDetector: DuplicateDetector

    public init(
        scanner: Scanner = Scanner(),
        classifier: ClassificationEngine = ClassificationEngine(),
        planner: PlanningEngine = PlanningEngine(),
        duplicateDetector: DuplicateDetector = DuplicateDetector()
    ) {
        self.scanner = scanner
        self.classifier = classifier
        self.planner = planner
        self.duplicateDetector = duplicateDetector
    }

    public func scanAndPlan(
        source: SourceFolder,
        at sourceURL: URL,
        sessionDirectoryName: String,
        rules: [UserRule] = [],
        exclusions: [ExclusionRule] = [],
        minimumAgeDays: Int = 0,
        renamePreferences: RenamePreferences = RenamePreferences(),
        existingRelativeDestinations: Set<String> = []
    ) async throws -> CleanupPlan {
        let items = try await scanner.scan(source: source, at: sourceURL)
        let ruleEngine = RuleEngine(rules: rules)
        let activeClassifier = exclusions.isEmpty ? classifier : ClassificationEngine(exclusions: exclusions)
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -max(0, minimumAgeDays),
            to: Date()
        ) ?? .distantPast
        var classifications: [UUID: Classification] = [:]
        var suggestedBasenames: [UUID: String] = [:]
        for item in items {
            if minimumAgeDays > 0,
               let itemDate = item.modificationDate ?? item.creationDate,
               itemDate > cutoff {
                continue
            }
            let localClassification = activeClassifier.classify(item)
            if localClassification.isExcluded || localClassification.isSensitive {
                classifications[item.id] = localClassification
            } else if let evaluation = ruleEngine.evaluate(item) {
                classifications[item.id] = evaluation.classification
                suggestedBasenames[item.id] = evaluation.suggestedBasename
            } else {
                classifications[item.id] = localClassification
            }
        }

        let duplicateEligibleItems = items.filter { item in
            guard let classification = classifications[item.id] else { return false }
            return !classification.isExcluded && !classification.isSensitive
        }
        let duplicateOriginals = await duplicateDetector.duplicateOriginals(
            among: duplicateEligibleItems,
            beneath: sourceURL
        )
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for (duplicateID, originalID) in duplicateOriginals {
            guard let original = itemsByID[originalID] else { continue }
            classifications[duplicateID] = Classification(
                category: .duplicates,
                confidence: .high,
                reason: "Content matches earlier item \(original.filename)"
            )
            suggestedBasenames[duplicateID] = itemsByID[duplicateID]?.basename
        }

        let activePlanner = renamePreferences == RenamePreferences()
            ? planner
            : PlanningEngine(sanitizer: FilenameSanitizer(preferences: renamePreferences))
        return activePlanner.makePlan(
            items: items,
            classifications: classifications,
            suggestedBasenames: suggestedBasenames,
            sessionDirectoryName: sessionDirectoryName,
            existingRelativeDestinations: existingRelativeDestinations
        )
    }
}
