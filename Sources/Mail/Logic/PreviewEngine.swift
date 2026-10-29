import Foundation

enum PreviewEngine {
    private static let lineBreaks = try? NSRegularExpression(pattern: #"\s+(?=(?:Am|On)\s)|(?<=:)\s*(?=[>›])"#)
    private static let quoteRuns = try? NSRegularExpression(pattern: #"(>\s*)+"#)
    private static let dividers = ["-----original", "-----ursprüngliche", "________________________________"]
    private static let sendLines = ["sent from my", "gesendet von meinem"]

    static func text(_ raw: String) -> String {
        var kept: [String] = []
        for line in raw.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if trimmed == "--" || trimmed == "\u{2014}" || dividers.contains(where: lower.hasPrefix) || sendLines.contains(where: lower.hasPrefix) { break }
            kept.append(trimmed)
        }
        var flat = ownText(broken(kept.joined(separator: "\n")))
        if let regex = quoteRuns {
            flat = regex.stringByReplacingMatches(in: flat, range: NSRange(flat.startIndex..., in: flat), withTemplate: " ")
        }
        let words = flat.split(whereSeparator: { $0.isWhitespace })
        var result = words.joined(separator: " ")
        while let last = result.last, "\u{2014}\u{2013}-".contains(last) { result.removeLast() }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func broken(_ text: String) -> String {
        guard let regex = lineBreaks else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n")
    }

    private static func ownText(_ text: String) -> String {
        var rest = text
        var own: [String] = []
        while true {
            let parts = Quoting.split(rest)
            own.append(parts.body)
            guard let quote = parts.quote else { break }
            rest = after(quote.text)
        }
        return own.joined(separator: " ")
    }

    private static func after(_ quote: String) -> String {
        let lines = quote.components(separatedBy: "\n").dropFirst()
        let tail = lines.drop { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || trimmed.hasPrefix(">") || trimmed.hasPrefix("\u{203A}")
        }
        return tail.joined(separator: "\n")
    }
}
