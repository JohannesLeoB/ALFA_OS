import Foundation

enum ReferenceEngine {
    static let maxLength = 35
    static let numberPrefixPattern = "^\\d{4}[_-]\\d{2,4}[_-]"

    static func commission(fromProjectName name: String) -> String {
        var text = name.trimmingCharacters(in: .whitespaces)
        if let regex = try? NSRegularExpression(pattern: numberPrefixPattern) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        }
        text = text.replacingOccurrences(of: "_", with: " ")
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        return text.trimmingCharacters(in: .whitespaces)
    }

    static func reference(projectNumber: String?, projectName: String?) -> String? {
        let commission = projectName.map(commission(fromProjectName:)).flatMap(nonEmpty)
        let number = projectNumber.map { $0.trimmingCharacters(in: .whitespaces) }.flatMap(nonEmpty)
        let parts = [commission, number].compactMap { $0 }
        guard parts.isEmpty == false else { return nil }
        return String(parts.joined(separator: " \u{00B7} ").prefix(maxLength))
    }

    private static func nonEmpty(_ text: String) -> String? {
        text.isEmpty ? nil : text
    }
}
