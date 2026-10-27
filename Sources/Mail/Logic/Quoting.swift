import Foundation

enum Quoting {
    static func split(_ text: String) -> (body: String, quote: Quote?) {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard let first = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix(">") || trimmed.hasPrefix("\u{203A}")
        }) else { return (text, nil) }
        var start = first
        var look = first - 1
        while look >= 0, lines[look].trimmingCharacters(in: .whitespaces).isEmpty { look -= 1 }
        if look >= 0 {
            let head = lines[look].trimmingCharacters(in: .whitespaces)
            let lower = head.lowercased()
            if head.hasSuffix(":"), lower.contains("schrieb") || lower.contains("wrote") { start = look }
        }
        let body = lines[..<start].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let quote = lines[start...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (body, Quote(text: quote, lines: lines[start...].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count))
    }
}
