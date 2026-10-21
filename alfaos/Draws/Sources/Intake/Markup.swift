import Foundation

enum Braces {
    static let pattern = try? NSRegularExpression(pattern: "\\{\\{\\{?\\s*([#^/&>!=]?)\\s*([^\\s}]*)\\s*\\}?\\}\\}")

    static func has(_ text: String) -> Bool {
        pattern?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    static func read(_ source: String, _ r: inout Ingested) {
        var names: [String] = []
        let whole = NSRange(source.startIndex..., in: source)
        for match in pattern?.matches(in: source, range: whole) ?? [] {
            guard let sigil = Range(match.range(at: 1), in: source), let name = Range(match.range(at: 2), in: source) else { continue }
            let tag = String(source[sigil]), value = String(source[name])
            if ["/", "!", "="].contains(tag) || value.isEmpty || value == "." { continue }
            if tag == ">" { r.note("mustache.partial"); continue }
            if !names.contains(value) { names.append(value) }
        }
        r.template = Template(source: source, variables: names)
    }
}

enum Markup {
    static let entities = ["&nbsp;": " ", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&amp;": "&"]

    static func html(_ source: String) -> String {
        var s = source
        for (pattern, with) in [("(?is)<(script|style)[^>]*>.*?</\\1>", ""), ("(?s)<!--.*?-->", ""), ("(?i)<br\\s*/?>|</(p|div|h[1-6]|li|tr|section|article)>", "\n"), ("<[^>]+>", "")] {
            s = s.replacingOccurrences(of: pattern, with: with, options: .regularExpression)
        }
        for (entity, char) in entities { s = s.replacingOccurrences(of: entity, with: char) }
        return s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func svg(_ data: Data) -> String {
        guard let root = Dom.parse(data) else { return "" }
        return root.all("text").map { $0.flat.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
