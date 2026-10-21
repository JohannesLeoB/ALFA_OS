import Foundation

public enum Initials {
    private static let particles: Set<String> = [
        "ii", "iii", "iv", "jr", "jr.", "sr", "sr.", "de", "la", "del", "y", "von", "van", "der", "den", "da", "di", "du"
    ]

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: true
        default: false
        }
    }

    private static func face(_ word: Substring) -> String {
        let letters = word.unicodeScalars.drop { !isLetter($0) }
        let text = String(String.UnicodeScalarView(letters))
        return text.first.map { String($0).uppercased() } ?? ""
    }

    public static func from(_ name: String) -> String {
        var text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: #"^An\s+(?=\S+\s+\S)"#, options: .regularExpression) {
            text.removeSubrange(range)
        }
        let words = text.split(whereSeparator: \.isWhitespace).filter {
            $0.unicodeScalars.contains(where: isLetter) && !particles.contains($0.lowercased())
        }
        guard let first = words.first, let last = words.last else { return "" }
        return words.count == 1 ? face(first) : face(first) + face(last)
    }

    public static func avatar(code: String, name: String) -> String {
        let own = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return own.isEmpty ? from(name) : own
    }
}
