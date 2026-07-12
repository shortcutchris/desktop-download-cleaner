import Foundation

public struct FilenameSanitizer: Sendable {
    public let maximumBasenameUTF8Length: Int
    public let preferences: RenamePreferences

    public init(
        maximumBasenameUTF8Length: Int = 180,
        preferences: RenamePreferences = RenamePreferences()
    ) {
        self.maximumBasenameUTF8Length = max(32, maximumBasenameUTF8Length)
        self.preferences = preferences
    }

    public func normalizedBasename(_ input: String) -> String {
        var value = input.precomposedStringWithCanonicalMapping
        value.unicodeScalars.removeAll { scalar in
            CharacterSet.controlCharacters.contains(scalar) || scalar.value == 0 || scalar == "/" || scalar == ":"
        }
        value = value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        value = removeRepeatedDownloadSuffix(from: value)
        if preferences.dateStyle == .iso8601 {
            value = normalizeDetectedDate(in: value)
        }
        switch preferences.namingStyle {
        case .natural:
            break
        case .hyphenated:
            value = value.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        case .underscored:
            value = value.replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
        }

        if value.isEmpty || value == "." || value == ".." {
            value = "Untitled"
        }
        return truncateUTF8(value, to: maximumBasenameUTF8Length)
    }

    public func suggestedFilename(for item: ScannedItem) -> String {
        let basename = normalizedBasename(item.basename)
        return filename(basename: basename, pathExtension: item.pathExtension)
    }

    public func filename(basename: String, pathExtension: String) -> String {
        let safeBasename = normalizedBasename(basename)
        guard !pathExtension.isEmpty else { return safeBasename }
        let safeExtension = pathExtension.filter { $0.isLetter || $0.isNumber }
        guard !safeExtension.isEmpty else { return safeBasename }
        return "\(safeBasename).\(safeExtension)"
    }

    public func collisionFilename(original: String, ordinal: Int) -> String {
        let url = URL(fileURLWithPath: original)
        let ext = url.pathExtension
        let basename = ext.isEmpty ? original : String(original.dropLast(ext.count + 1))
        let suffix = switch preferences.collisionSuffixStyle {
        case .enDash: " – \(ordinal)"
        case .parentheses: " (\(ordinal))"
        case .hyphen: " - \(ordinal)"
        }
        let availableBytes = max(1, maximumBasenameUTF8Length - suffix.utf8.count)
        let adjusted = truncateUTF8(basename, to: availableBytes) + suffix
        return ext.isEmpty ? adjusted : "\(adjusted).\(ext)"
    }

    private func removeRepeatedDownloadSuffix(from value: String) -> String {
        value.replacingOccurrences(
            of: #"(?:\s*\(\d+\)|\s+-\s+copy)+$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        ).trimmingCharacters(in: .whitespaces)
    }

    private func normalizeDetectedDate(in value: String) -> String {
        let pattern = #"(?<!\d)(\d{4})[._-](\d{1,2})[._-](\d{1,2})(?!\d)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = expression.firstMatch(in: value, range: range),
              let yearRange = Range(match.range(at: 1), in: value),
              let monthRange = Range(match.range(at: 2), in: value),
              let dayRange = Range(match.range(at: 3), in: value),
              let fullRange = Range(match.range(at: 0), in: value),
              let month = Int(value[monthRange]),
              let day = Int(value[dayRange]),
              (1...12).contains(month),
              (1...31).contains(day) else { return value }
        let replacement = "\(value[yearRange])-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
        return value.replacingCharacters(in: fullRange, with: replacement)
    }

    private func truncateUTF8(_ value: String, to maximumBytes: Int) -> String {
        guard value.utf8.count > maximumBytes else { return value }
        var result = value
        while result.utf8.count > maximumBytes, !result.isEmpty {
            result.removeLast()
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
