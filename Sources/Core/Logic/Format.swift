import Foundation

public enum Format {
    public static func number(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "de_DE")))
    }

    public static func bytes(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: Int64(count))
    }
}

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

public enum PlaceholderEngine {
    public static func fill(_ template: String, _ values: [String]) -> String {
        var result = ""
        var index = template.startIndex
        while index < template.endIndex {
            if template[index] == "{", let close = template[index...].firstIndex(of: "}"),
               let number = position(template[template.index(after: index)..<close]), values.indices.contains(number - 1) {
                result += values[number - 1]
                index = template.index(after: close)
            } else {
                result.append(template[index])
                index = template.index(after: index)
            }
        }
        return result
    }

    private static func position(_ digits: Substring) -> Int? {
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(digits)
    }
}

public enum AddressSplitParser {
    public struct Result: Equatable, Sendable {
        public let street: String
        public let houseNumber: String?
        let unclear: Bool

        init(street: String, houseNumber: String?, unclear: Bool = false) {
            self.street = street
            self.houseNumber = houseNumber
            self.unclear = unclear
        }
    }

    private static let extraTokens: Set<String> = [
        "stock", "og", "eg", "hinterhof", "hinterhaus", "vorderhaus", "vh", "hh", "etage",
        "aufgang", "eingang", "wareneingang", "bitte", "gebäude", "haus", "links", "rechts",
        "hof", "seitenflügel", "dachgeschoss", "keller", "zimmer", "büro", "planta", "apt",
        "unit", "of", "co", "app"
    ]

    static func hasExtra(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("c/o") { return true }
        let tokens = lower.split(whereSeparator: {
            $0.isLetter == false && $0.isNumber == false && $0 != "-"
        })
        return tokens.contains { extraTokens.contains(String($0)) }
    }

    public static func parse(_ line: String) -> Result {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        guard text.isEmpty == false else { return .init(street: "", houseNumber: nil) }

        guard text.rangeOfCharacter(from: .decimalDigits) != nil else {
            return .init(street: text, houseNumber: nil)
        }

        if hasExtra(text) {
            return .init(street: text, houseNumber: nil, unclear: true)
        }

        if text.contains(" - ") || text.contains(" – ") {
            return .init(street: text, houseNumber: nil, unclear: true)
        }

        let parts = text.split(separator: " ").map(String.init)

        if parts.filter({ isHouseNumber($0.replacingOccurrences(of: ",", with: "")) }).count > 1 {
            return .init(street: text, houseNumber: nil, unclear: true)
        }

        guard parts.count >= 2 else {
            return .init(street: text, houseNumber: nil, unclear: true)
        }

        if isHouseNumber(parts[0].replacingOccurrences(of: ",", with: "")) {
            let number = parts[0].replacingOccurrences(of: ",", with: "")
            let rest = parts.dropFirst().joined(separator: " ")
            guard rest.isEmpty == false else { return .init(street: text, houseNumber: nil, unclear: true) }
            return .init(street: rest, houseNumber: number)
        }

        let last = parts[parts.count - 1]
        guard isHouseNumber(last) else {
            return .init(street: text, houseNumber: nil, unclear: true)
        }
        let street = parts.dropLast().joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
        guard street.isEmpty == false,
              street.rangeOfCharacter(from: .letters) != nil else {
            return .init(street: text, houseNumber: nil, unclear: true)
        }
        return .init(street: street, houseNumber: last)
    }

    static func isHouseNumber(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: " ,."))
        guard let first = trimmed.first, first.isNumber, first.isASCII else { return false }
        if trimmed.count >= 5, trimmed.allSatisfy({ $0.isNumber }) { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-/")
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }

        var letterRun = 0
        for character in trimmed {
            if character.isLetter {
                letterRun += 1
                if letterRun > 3 { return false }
            } else {
                letterRun = 0
            }
        }
        return true
    }
}
