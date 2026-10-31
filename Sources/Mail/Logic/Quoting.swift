import Core
import Foundation

public struct QuoteTexts: Sendable {
    public var dated: String
    public var undated: String
    public var locale: Locale

    public init(dated: String = "{1}, {2}:", undated: String = "{1}:", locale: Locale = .current) {
        self.dated = dated
        self.undated = undated
        self.locale = locale
    }
}

enum Quoting {
    private static let maxAttributionLines = 3
    private static let starters = ["on ", "am ", "le ", "el ", "il ", "op ", "den ", "em ", "dne ", "w dniu "]
    private static let verbs = ["wrote", "schrieb", "a \u{E9}crit", "a ecrit", "escribi\u{F3}", "escribio", "ha scritto", "skrev",
                                "schreef", "escreveu", "napisa\u{142}"]
    private static let looseVerbs = ["schrieb", "wrote"]
    private static let dividerNames = ["original message", "urspr\u{FC}ngliche nachricht", "originalnachricht", "original-nachricht",
                                       "message d'origine", "mensaje original", "messaggio originale"]
    private static let dividerHeads = ["from:", "von:", "de:", "de :", "van:", "da:"]
    private static let minimumRule = 20

    static func split(_ text: String) -> (body: String, quote: Quote?) {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard let first = quoteStart(lines) else { return (text, nil) }
        var start = first.index
        var attribution: String?
        if first.quoted {
            var look = first.index - 1
            while look >= 0, blank(lines[look]) { look -= 1 }
            if look >= 0, let begin = attributionStart(lines, endingAt: look) {
                attribution = flat(lines[begin...look].joined(separator: " "))
                start = begin
            }
        }
        let body = lines[..<start].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = (attribution.map { [$0] } ?? []) + lines[first.index...]
        let quote = quoted.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (body, Quote(text: quote, lines: quoted.filter { !blank($0) }.count))
    }

    static func isAttribution(_ text: String) -> Bool {
        let lower = flat(text).lowercased()
        guard lower.hasSuffix(":"), starters.contains(where: lower.hasPrefix) else { return false }
        return verbs.contains { lower.contains($0) }
    }

    static func attributionStart(_ lines: [String], endingAt end: Int) -> Int? {
        var begin = end
        let floor = max(0, end - maxAttributionLines + 1)
        while begin >= floor, !blank(lines[begin]) {
            if isAttribution(lines[begin...end].joined(separator: " ")) { return begin }
            begin -= 1
        }
        let last = flat(lines[end]).lowercased()
        return last.hasSuffix(":") && looseVerbs.contains(where: last.contains) ? end : nil
    }

    static func attribution(_ sender: String, at date: Date?, dated: String, undated: String, locale: Locale = .current,
                            timeZone: TimeZone = .current) -> String {
        guard let date else { return PlaceholderEngine.fill(undated, [sender]) }
        let when = date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, timeZone: timeZone))
        return PlaceholderEngine.fill(dated, [when, sender])
    }

    static func flat(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func blank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func quoteStart(_ lines: [String]) -> (index: Int, quoted: Bool)? {
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(">") || trimmed.hasPrefix("\u{203A}") { return (index, true) }
            if isDivider(trimmed, next: lines.dropFirst(index + 1).first { !blank($0) }) { return (index, false) }
        }
        return nil
    }

    private static func isDivider(_ line: String, next: String?) -> Bool {
        if line.count >= minimumRule, line.allSatisfy({ $0 == "_" }) {
            let head = next?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            return dividerHeads.contains(where: head.hasPrefix)
        }
        guard line.hasPrefix("---") else { return false }
        let name = line.drop { $0 == "-" || $0 == " " }.lowercased()
        return dividerNames.contains(where: name.hasPrefix)
    }
}

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

public enum RichTextEngine {
    public static func marker(_ kind: ListKind, position: Int) -> String {
        switch kind {
        case .bullet: "\u{2022} "
        case .number: String(position) + ". "
        }
    }

    public static func html(_ paragraphs: [RichParagraph]) -> String? {
        guard paragraphs.contains(where: { $0.list != nil || $0.runs.contains { !$0.plain } }) else { return nil }
        var out = ""
        var open: ListKind?
        for paragraph in paragraphs {
            if paragraph.list != open {
                if let open { out += "</" + tag(open) + ">" }
                if let next = paragraph.list { out += "<" + tag(next) + ">" }
                open = paragraph.list
            }
            let inner = paragraph.runs.map(run).joined()
            if open != nil {
                out += "<li>" + inner + "</li>"
            } else {
                out += "<div>" + (inner.isEmpty ? "<br>" : inner) + "</div>"
            }
        }
        if let open { out += "</" + tag(open) + ">" }
        return out
    }

    private static func tag(_ kind: ListKind) -> String {
        kind == .bullet ? "ul" : "ol"
    }

    private static func run(_ run: RichRun) -> String {
        var text = escape(run.text)
        if run.underline { text = "<u>" + text + "</u>" }
        if run.italic { text = "<i>" + text + "</i>" }
        if run.bold { text = "<b>" + text + "</b>" }
        if let link = run.link { text = "<a href=\"" + escape(link) + "\">" + text + "</a>" }
        return text
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
