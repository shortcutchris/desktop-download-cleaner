import DesktopCleanerCore
import Foundation

func makeItem(
    filename: String,
    typeIdentifier: String? = nil,
    isPackage: Bool = false,
    relativePath: String? = nil
) -> ScannedItem {
    ScannedItem(
        sourceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        relativePath: relativePath ?? filename,
        filename: filename,
        pathExtension: URL(fileURLWithPath: filename).pathExtension,
        typeIdentifier: typeIdentifier,
        identity: filename,
        isPackage: isPackage
    )
}

