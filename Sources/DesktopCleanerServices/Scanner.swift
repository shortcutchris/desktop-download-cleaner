import DesktopCleanerCore
import Foundation

public enum ScannerError: Error, Equatable {
    case sourceIsNotDirectory
    case sourceUnavailable
}

public struct Scanner: Sendable {
    public init() {}

    public func scan(source: SourceFolder, at rootURL: URL) async throws -> [ScannedItem] {
        let rootValues = try rootURL.resourceValues(forKeys: [.isDirectoryKey])
        guard rootValues.isDirectory == true else { throw ScannerError.sourceIsNotDirectory }

        var results: [ScannedItem] = []
        try await scanDirectory(
            rootURL,
            rootURL: rootURL,
            source: source,
            currentDepth: 0,
            results: &results
        )
        return results.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private func scanDirectory(
        _ directoryURL: URL,
        rootURL: URL,
        source: SourceFolder,
        currentDepth: Int,
        results: inout [ScannedItem]
    ) async throws {
        try Task.checkCancellation()
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
            .isAliasFileKey, .isHiddenKey, .fileSizeKey, .creationDateKey,
            .contentModificationDateKey, .typeIdentifierKey, .fileResourceIdentifierKey
        ]
        let children = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(keys),
            options: []
        )

        for child in children.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            try Task.checkCancellation()
            let values = try child.resourceValues(forKeys: keys)

            let isDirectory = values.isDirectory == true
            let isPackage = values.isPackage == true
            let isSymbolicLink = values.isSymbolicLink == true

            if isDirectory, !isPackage, !isSymbolicLink {
                if currentDepth < source.scanDepth {
                    try await scanDirectory(
                        child,
                        rootURL: rootURL,
                        source: source,
                        currentDepth: currentDepth + 1,
                        results: &results
                    )
                }
                continue
            }

            let relativePath = Self.relativePath(of: child, beneath: rootURL)
            let resourceIdentifier = values.fileResourceIdentifier.map(String.init(describing:)) ?? "unavailable"
            let identity = "\(resourceIdentifier)|\(values.fileSize ?? 0)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"

            results.append(ScannedItem(
                sourceID: source.id,
                relativePath: relativePath,
                filename: child.lastPathComponent,
                pathExtension: child.pathExtension,
                typeIdentifier: values.typeIdentifier,
                size: Int64(values.fileSize ?? 0),
                creationDate: values.creationDate,
                modificationDate: values.contentModificationDate,
                identity: identity,
                isPackage: isPackage,
                isAlias: values.isAliasFile == true,
                isSymbolicLink: isSymbolicLink,
                isHidden: values.isHidden == true
            ))
        }
    }

    private static func relativePath(of child: URL, beneath root: URL) -> String {
        let rootPath = root.standardizedFileURL.path(percentEncoded: false)
        let childPath = child.standardizedFileURL.path(percentEncoded: false)
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard childPath.hasPrefix(prefix) else { return child.lastPathComponent }
        return String(childPath.dropFirst(prefix.count))
    }
}
