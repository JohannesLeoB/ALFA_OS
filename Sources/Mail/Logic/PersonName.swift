import Core
import Foundation

public enum PersonName {
    private static let ellipsis = "\u{2026}"

    public static func initials(_ name: String) -> String {
        Initials.from(name)
    }

    public static func middle(_ text: String, limit: Int) -> String {
        let letters = Array(text)
        guard letters.count > limit else { return text }
        let head = Int((Double(limit - 1) * NameLimit.middleHead).rounded(.up))
        let tail = limit - 1 - head
        return String(letters.prefix(head)) + ellipsis + String(letters.suffix(tail))
    }

    static func display(_ raw: String) -> (name: String, address: String) {
        let entry = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = entry.lastIndex(of: "<"), let close = entry.lastIndex(of: ">"), open < close else {
            return ("", entry)
        }
        var name = entry[entry.startIndex..<open].trimmingCharacters(in: .whitespaces)
        if name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 { name = String(name.dropFirst().dropLast()) }
        return (name, String(entry[entry.index(after: open)..<close]))
    }
}

public enum NameLimit {
    static let person = 40
    static let chip = 30
    static let summary = 30
    static let sender = 40
    static let middleHead = 0.55
    static let personAddress = 44
    static let firstName = 24
    static let suggestionAddress = 40
    public static let recipientsInline = 2
}
