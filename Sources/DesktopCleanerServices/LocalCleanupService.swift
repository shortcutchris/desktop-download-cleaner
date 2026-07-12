import DesktopCleanerCore
import Foundation

public struct LocalCleanupService: Sendable {
    private let scanner: Scanner
    private let classifier: ClassificationEngine
    private let planner: PlanningEngine

    public init(
        scanner: Scanner = Scanner(),
        classifier: ClassificationEngine = ClassificationEngine(),
        planner: PlanningEngine = PlanningEngine()
    ) {
        self.scanner = scanner
        self.classifier = classifier
        self.planner = planner
    }

    public func scanAndPlan(
        source: SourceFolder,
        at sourceURL: URL,
        sessionDirectoryName: String,
        rules: [UserRule] = [],
        exclusions: [ExclusionRule] = [],
        minimumAgeDays: Int = 0,
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
        return planner.makePlan(
            items: items,
            classifications: classifications,
            suggestedBasenames: suggestedBasenames,
            sessionDirectoryName: sessionDirectoryName,
            existingRelativeDestinations: existingRelativeDestinations
        )
    }
}
