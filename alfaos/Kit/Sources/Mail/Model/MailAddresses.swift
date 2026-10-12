import Foundation

enum MailAddresses {
    static func split(_ raw: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var quoted = false
        var angled = false
        for character in raw {
            switch character {
            case "\"": quoted.toggle(); current.append(character)
            case "<" where !quoted: angled = true; current.append(character)
            case ">" where !quoted: angled = false; current.append(character)
            case "," where !quoted && !angled:
                parts.append(current)
                current = ""
            default: current.append(character)
            }
        }
        parts.append(current)
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static func email(_ entry: String) -> String {
        if let open = entry.lastIndex(of: "<"), let close = entry.lastIndex(of: ">"), open < close {
            return String(entry[entry.index(after: open)..<close]).lowercased()
        }
        return entry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func plainText(_ html: String) -> String {
        MailText.plain(html)
    }
}

public enum MailText {
    public static func plain(_ html: String) -> String {
        html.replacingOccurrences(of: "(?is)<(script|style)[^>]*>.*?</\\1>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
