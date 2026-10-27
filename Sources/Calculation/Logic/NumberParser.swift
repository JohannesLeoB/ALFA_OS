import Foundation

enum NumberParser {
    static func decimal(_ input: String) -> Decimal? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withoutCurrency = trimmed
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: String
        if withoutCurrency.contains(",") {
            normalized = withoutCurrency
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        } else {
            normalized = withoutCurrency
        }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func double(_ input: String) -> Double? {
        guard let decimal = decimal(input) else { return nil }
        return decimal.double
    }

    static let integerWords: [String: Int] = [
        "ein": 1, "eine": 1, "einen": 1, "eins": 1, "zwei": 2, "drei": 3,
        "vier": 4, "fünf": 5, "fuenf": 5, "sechs": 6, "sieben": 7,
        "acht": 8, "neun": 9, "zehn": 10, "elf": 11, "zwölf": 12,
        "zwoelf": 12, "dreizehn": 13, "vierzehn": 14, "fünfzehn": 15,
        "fuenfzehn": 15,
    ]

    static func integerWord(_ input: String) -> Int? {
        integerWords[input.lowercased()]
    }
}
