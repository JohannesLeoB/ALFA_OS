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

    /// A token that is a color: 3, 4, 6 or 8 hex digits, with "#". Without "#", 6 or 8 digits with at least one number.
    private static func color(in token: String) -> Parsed? {
        let hadHash = token.hasPrefix("#")
        let body = hadHash ? String(token.dropFirst()) : token
        guard [3, 4, 6, 8].contains(body.count), body.allSatisfy(\.isHexDigit), body.allSatisfy(\.isASCII) else { return nil }
        if !hadHash {
            guard body.count >= 6, body.contains(where: \.isNumber) else { return nil }
        }
        let full = body.count <= 4 ? body.map { "\($0)\($0)" }.joined() : body
        return Parsed(hex: "#" + full.uppercased(), hadHash: hadHash, digits: body.count)
    }
}
