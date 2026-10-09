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

    /// The text with every run of white space made into one space, and without white space at the ends.
    static func tidy(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The URL of a web address. Only http and https are taken; anything else gives nil.
    static func webURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    /// The time for a Unix time stamp in seconds, or nil for text that is not a finite number.
    static func date(unixSeconds text: String?) -> Date? {
        guard let text, let seconds = Double(text.trimmingCharacters(in: .whitespaces)), seconds.isFinite else {
            return nil
        }
        return Date(timeIntervalSince1970: seconds)
    }
}
