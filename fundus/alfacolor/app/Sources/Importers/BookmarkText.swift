import Foundation

/// Text helpers that both bookmark formats share.
enum BookmarkText {
    /// The text with the common entities and numeric character references decoded. Unknown entities stay as they are.
    static func decodingEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let afterAmp = rest[rest.index(after: amp)...]
            if let semi = afterAmp.prefix(12).firstIndex(of: ";"), let decoded = decodeEntity(afterAmp[..<semi]) {
                result += decoded
                rest = afterAmp[afterAmp.index(after: semi)...]
            } else {
                result += "&"
                rest = afterAmp
            }
        }
        result += rest
        return result
    }

    private static func decodeEntity(_ name: Substring) -> String? {
        switch String(name) {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        case "nbsp": return "\u{A0}"
        default:
            guard name.first == "#" else { return nil }
            let digits = name.dropFirst()
            let value: UInt32?
            if digits.first == "x" || digits.first == "X" {
                value = UInt32(digits.dropFirst(), radix: 16)
            } else {
                value = UInt32(digits)
            }
            guard let value, value > 0, let scalar = Unicode.Scalar(value) else { return nil }
            return String(Character(scalar))
        }
    }

    /// The longest title or folder name that is taken, in characters.
    static let maxTitleLength = 200
    /// The longest web address that is taken, in characters.
    static let maxAddressLength = 2048
    /// The range of the dates that are taken, as Unix seconds: 1970 to 2100.
    static let dateRange: ClosedRange<Double> = 0...4_102_444_800

    /// The text with every run of white space made into one space, and without white space at the ends.
    static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// A title or folder name: tidied, and cut to `maxTitleLength` characters.
    static func clip(_ text: String) -> String {
        String(tidy(text).prefix(maxTitleLength)).trimmingCharacters(in: .whitespaces)
    }

    /// A link title. A title that is empty after tidying is the host of the address.
    static func linkTitle(_ text: String, url: URL) -> String {
        let title = clip(text)
        return title.isEmpty ? clip(url.host ?? url.absoluteString) : title
    }

    /// The URL of a web address. Only http and https are taken, and only up to `maxAddressLength` characters.
    static func webURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= maxAddressLength, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    /// The time for a Unix time stamp in seconds, or nil for a value outside `dateRange`, NaN and infinity.
    static func date(unixSeconds seconds: Double) -> Date? {
        guard dateRange.contains(seconds) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    /// The time for the text of a Unix time stamp in seconds, or nil for text that is not a number in `dateRange`.
    static func date(unixSeconds text: String?) -> Date? {
        guard let text, let seconds = Double(text.trimmingCharacters(in: .whitespaces)) else { return nil }
        return date(unixSeconds: seconds)
    }
}
