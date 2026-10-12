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
        let stripped = html
            .replacingOccurrences(of: "(?is)<(script|style)[^>]*>.*?</\\1>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return decodeEntities(stripped)
    }

    static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "auml": "ä", "ouml": "ö", "uuml": "ü", "Auml": "Ä", "Ouml": "Ö", "Uuml": "Ü", "szlig": "ß",
        "euro": "€", "ndash": "–", "mdash": "—", "hellip": "…", "laquo": "«", "raquo": "»",
        "bdquo": "„", "ldquo": "“", "rdquo": "”", "lsquo": "‘", "rsquo": "’", "copy": "©", "reg": "®"
    ]

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semi = after.firstIndex(of: ";"), after.distance(from: after.startIndex, to: semi) <= 10 {
                let name = String(after[..<semi])
                if let value = entity(name) {
                    result += value
                    rest = after[after.index(after: semi)...]
                    continue
                }
            }
            result += "&"
            rest = after
        }
        return result + rest
    }

    static func entity(_ name: String) -> String? {
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            return UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        if name.hasPrefix("#") {
            return UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return namedEntities[name]
    }
}
