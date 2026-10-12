import Foundation

public struct MailAddress: Identifiable, Hashable, Sendable {
    public let name: String
    public let email: String
    public var id: String { email.isEmpty ? name : email }

    public init(name: String, email: String) {
        self.name = name
        self.email = email
    }

    public static func domain(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let at = value.lastIndex(of: "@") else { return "" }
        return String(value[value.index(after: at)...]).trimmingCharacters(in: CharacterSet(charactersIn: "> "))
    }

    public static func initials(_ raw: String) -> String {
        let name = displayName(raw)
        let words = name.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" })
            .filter { $0.isEmpty == false }
        if words.count >= 2,
           let a = words.first?.first, let b = words.last?.first {
            return "\(a)\(b)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    public static func displayName(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let angle = value.firstIndex(of: "<") {
            let before = value[value.startIndex..<angle]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \""))
            if before.isEmpty == false { return before }
            let inside = value[angle...].trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
            return String(inside.split(separator: "@").first ?? "?")
        }
        if value.contains("@") { return String(value.split(separator: "@").first ?? "?") }
        return value.isEmpty ? "?" : value
    }

    public static func emailAddress(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = value.lastIndex(of: "<"), let close = value.lastIndex(of: ">"), open < close {
            return String(value[value.index(after: open)..<close])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.contains("@") ? value.trimmingCharacters(in: CharacterSet(charactersIn: " \"")) : ""
    }

    public static func formatted(name: String, email: String) -> String {
        let needsQuotes = name.contains(",") || name.contains("<") || name.contains(">") || name.contains("@")
        let shown = needsQuotes ? "\"" + name.replacingOccurrences(of: "\"", with: "") + "\"" : name
        return "\(shown) <\(email)>"
    }

    public static func pieces(_ raw: String) -> [String] {
        let quoteCount = raw.filter { $0 == "\"" }.count
        guard quoteCount % 2 == 0 else {
            return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
        }
        var out: [String] = []
        var current = ""
        var inQuotes = false
        var angleDepth = 0
        for character in raw {
            switch character {
            case "\"":
                inQuotes.toggle()
                current.append(character)
            case "<" where inQuotes == false:
                angleDepth += 1
                current.append(character)
            case ">" where inQuotes == false:
                angleDepth = max(0, angleDepth - 1)
                current.append(character)
            case "," where inQuotes == false && angleDepth == 0:
                out.append(current)
                current = ""
            default:
                current.append(character)
            }
        }
        out.append(current)
        return out.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }
    }

    public static func addresses(_ raw: String) -> [MailAddress] {
        var seen = Set<String>()
        var out: [MailAddress] = []
        for text in pieces(raw) {
            let email = emailAddress(text)
            let name = displayName(text)
            guard name.isEmpty == false, name != "?" || email.isEmpty == false else { continue }
            let key = email.isEmpty ? name.lowercased() : email.lowercased()
            guard seen.insert(key).inserted else { continue }
            out.append(MailAddress(name: name, email: email))
        }
        return out
    }

    public static func shortNames(_ raw: String) -> String {
        pieces(raw)
            .map { displayName($0) }
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }
}
