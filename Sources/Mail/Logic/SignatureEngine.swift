import Foundation

enum SignatureEngine {
    private static let gap = "\n\n"

    static func inserted(_ signature: String, into body: String, aboveQuote: Bool) -> String {
        if blank(body) { return gap + signature }
        if aboveQuote, let start = quoteStart(body) {
            let lines = body.components(separatedBy: "\n")
            let before = lines[..<start].joined(separator: "\n")
            let after = lines[start...].joined(separator: "\n")
            return (blank(before) ? gap : trimmed(before) + gap) + signature + gap + after
        }
        return trimmed(body) + gap + signature
    }

    static func replaced(_ old: String, with new: String, in body: String) -> String? {
        body.range(of: old, options: .backwards).map { body.replacingCharacters(in: $0, with: new) }
    }

    static func removed(_ old: String, from body: String) -> String? {
        guard let range = body.range(of: old, options: .backwards) else { return nil }
        let before = String(body[..<range.lowerBound])
        let after = String(body[range.upperBound...]).drop { $0 == "\n" }
        switch (blank(before), blank(String(after))) {
        case (true, true): return ""
        case (true, false): return gap + after
        case (false, true): return trimmed(before)
        case (false, false): return trimmed(before) + gap + after
        }
    }

    static func htmlBlock(_ signature: String) -> String {
        signature.components(separatedBy: "\n").map { "<div>" + ($0.isEmpty ? "<br>" : RichTextEngine.escape($0)) + "</div>" }.joined()
    }

    static func htmlInserted(_ signature: String, into html: String) -> String {
        html + emptyLine + htmlBlock(signature)
    }

    static func htmlReplaced(_ old: String, with new: String, in html: String) -> String? {
        replaced(htmlBlock(old), with: htmlBlock(new), in: html)
    }

    static func htmlRemoved(_ old: String, from html: String) -> String? {
        let block = htmlBlock(old)
        guard let range = html.range(of: block, options: .backwards) else { return nil }
        var start = range.lowerBound
        if html[..<start].hasSuffix(emptyLine) { start = html.index(start, offsetBy: -emptyLine.count) }
        return String(html[..<start]) + html[range.upperBound...]
    }

    private static let emptyLine = "<div><br></div>"

    private static func quoteStart(_ body: String) -> Int? {
        let lines = body.components(separatedBy: "\n")
        guard let first = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(">") }) else { return nil }
        return first > 0 && !blank(lines[first - 1]) ? first - 1 : first
    }

    private static func blank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func trimmed(_ text: String) -> String {
        var end = text.endIndex
        while end > text.startIndex, text[text.index(before: end)] == "\n" { end = text.index(before: end) }
        return String(text[..<end])
    }
}
