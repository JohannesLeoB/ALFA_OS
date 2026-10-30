import Foundation

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
