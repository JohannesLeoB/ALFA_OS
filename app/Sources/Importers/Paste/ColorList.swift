import Foundation

/// One color of a pasted list. `hex` is "#RRGGBB" or "#RRGGBBAA" in upper case.
public struct ColorEntry: Equatable, Sendable {
    public var hex: String
    public var name: String?
    public init(hex: String, name: String? = nil) { self.hex = hex; self.name = name }
}

/// Reads a list of colors: one color per line, or several separated by spaces, commas or semicolons.
/// A line can end with a name ("#E5007D Magenta"). Every line must be a color; one other line makes it no list.
enum ColorList {
    static let maxEntries = 500
    private static let maxNameWords = 5

    static func parse(_ text: String) -> [ColorEntry]? {
        var entries: [ColorEntry] = []
        var needsCompany = false
        for line in text.split(whereSeparator: \.isNewline) {
            let tokens = line.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == " " || $0 == "\t" }).map(String.init)
            guard !tokens.isEmpty else { continue }
            let colors = tokens.map(color(in:))
            if colors.allSatisfy({ $0 != nil }) {
                for case let color? in colors {
                    entries.append(ColorEntry(hex: color.hex))
                    if !color.hadHash { needsCompany = true }
                }
            } else if let first = colors[0], first.digits >= 6, colors.dropFirst().allSatisfy({ $0 == nil }) {
                let name = tokens.dropFirst().filter { !["-", "–", ":", "="].contains($0) }
                guard !name.isEmpty, name.count <= maxNameWords else { return nil }
                entries.append(ColorEntry(hex: first.hex, name: name.joined(separator: " ")))
                if !first.hadHash { needsCompany = true }
            } else {
                return nil
            }
            if entries.count > maxEntries { return nil }
        }
        // A bare word of hex digits ("decade") is not a color on its own.
        if needsCompany && entries.count < 2 { return nil }
        return entries.isEmpty ? nil : entries
    }

    private struct Parsed {
        var hex: String
        var hadHash: Bool
        var digits: Int
    }

    /// A single rgb() or rgba() color, as CSS writes it. An alpha below one adds the alpha byte.
    static func rgb(_ text: String) -> ColorEntry? {
        let pattern = #"^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([\d.]+)\s*)?\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        func part(_ index: Int) -> String? { Range(match.range(at: index), in: text).map { String(text[$0]) } }
        let channels = (1...3).compactMap { part($0).flatMap { Int($0) } }
        guard channels.count == 3, channels.allSatisfy({ $0 <= 255 }) else { return nil }
        var hex = channels.map(hexByte).joined()
        if let alphaText = part(4) {
            guard let alpha = Double(alphaText), (0...1).contains(alpha) else { return nil }
            hex += hexByte(Int((alpha * 255).rounded()))
        }
        return ColorEntry(hex: "#" + hex)
    }

    private static func hexByte(_ value: Int) -> String {
        let digits = String(value, radix: 16, uppercase: true)
        return digits.count < 2 ? "0" + digits : digits
    }

    /// A token that is a color: 6 or 8 hex digits, with "#". Short forms ("#fff") are no color on their own.
    /// Without "#", 6 or 8 digits with a letter and a digit: "123456" is a number, "decade" a word.
    private static func color(in token: String) -> Parsed? {
        let hadHash = token.hasPrefix("#")
        let body = hadHash ? String(token.dropFirst()) : token
        guard [6, 8].contains(body.count), body.allSatisfy(\.isHexDigit), body.allSatisfy(\.isASCII) else { return nil }
        if !hadHash {
            guard body.contains(where: \.isNumber), body.contains(where: \.isLetter) else { return nil }
        }
        return Parsed(hex: "#" + body.uppercased(), hadHash: hadHash, digits: body.count)
    }
}
