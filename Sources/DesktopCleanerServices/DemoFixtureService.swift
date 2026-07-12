import DesktopCleanerCore
import Foundation

public struct DemoFixture: Sendable {
    public let source: SourceFolder
    public let sourceURL: URL
    public let reviewRootURL: URL

    public init(source: SourceFolder, sourceURL: URL, reviewRootURL: URL) {
        self.source = source
        self.sourceURL = sourceURL
        self.reviewRootURL = reviewRootURL
    }
}

public struct DemoFixtureService: Sendable {
    public init() {}

    public func create() throws -> DemoFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopCleaner Demo \(UUID().uuidString)", isDirectory: true)
        let sourceURL = root.appendingPathComponent("Downloads Sample", isDirectory: true)
        let reviewURL = root.appendingPathComponent("Tidy Review", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: reviewURL, withIntermediateDirectories: true)

        let fixtures: [(String, String)] = [
            ("Project Proposal (2).pdf", "Desktop Cleaner sample proposal"),
            ("Screenshot 2026-07-12 at 10.42.18.png", "sample image"),
            ("customer-export  final.csv", "name,email\nSample,sample@example.invalid"),
            ("release-build.zip", "sample archive"),
            ("notes  from kickoff.txt", "sample notes"),
            ("server.pem", "sample sensitive placeholder")
        ]
        for (name, contents) in fixtures {
            try Data(contents.utf8).write(to: sourceURL.appendingPathComponent(name))
        }
        return DemoFixture(
            source: SourceFolder(displayName: "Downloads Sample"),
            sourceURL: sourceURL,
            reviewRootURL: reviewURL
        )
    }
}

