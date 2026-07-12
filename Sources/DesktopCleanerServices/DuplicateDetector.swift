import CryptoKit
import DesktopCleanerCore
import Foundation

public struct DuplicateDetector: Sendable {
    public init() {}

    public func duplicateOriginals(
        among items: [ScannedItem],
        beneath rootURL: URL
    ) async -> [UUID: UUID] {
        let candidates = items
            .filter { $0.size > 0 && !$0.isPackage && !$0.isAlias && !$0.isSymbolicLink }
            .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        let sizeGroups = Dictionary(grouping: candidates, by: \.size).values.filter { $0.count > 1 }
        var originalsByDigest: [String: UUID] = [:]
        var duplicates: [UUID: UUID] = [:]

        for group in sizeGroups {
            for item in group {
                if Task.isCancelled { return duplicates }
                guard let url = containedURL(relativePath: item.relativePath, root: rootURL),
                      let digest = try? digest(of: url) else { continue }
                if let originalID = originalsByDigest[digest] {
                    duplicates[item.id] = originalID
                } else {
                    originalsByDigest[digest] = item.id
                }
            }
        }
        return duplicates
    }

    private func digest(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func containedURL(relativePath: String, root: URL) -> URL? {
        guard !relativePath.hasPrefix("/"),
              !relativePath.split(separator: "/").contains("..") else { return nil }
        let standardizedRoot = root.standardizedFileURL
        let candidate = standardizedRoot.appendingPathComponent(relativePath).standardizedFileURL
        let prefix = standardizedRoot.path.hasSuffix("/") ? standardizedRoot.path : standardizedRoot.path + "/"
        return candidate.path.hasPrefix(prefix) ? candidate : nil
    }
}
