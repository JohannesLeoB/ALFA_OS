import Core
import Foundation

enum AddressListParser {
    static func split(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quoted = false
        var angle = 0
        var comment = 0
        var escaped = false
        for character in text {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            switch character {
            case "\\" where quoted || comment > 0:
                escaped = true
                current.append(character)
            case "\"" where comment == 0:
                quoted.toggle()
                current.append(character)
            case "<" where !quoted && comment == 0:
                angle += 1
                current.append(character)
            case ">" where !quoted && comment == 0:
                angle = max(0, angle - 1)
                current.append(character)
            case "(" where !quoted:
                comment += 1
                current.append(character)
            case ")" where !quoted:
                comment = max(0, comment - 1)
                current.append(character)
            case "," where !quoted && angle == 0 && comment == 0, ";" where !quoted && angle == 0 && comment == 0:
                result.append(current)
                current = ""
            default:
                current.append(character)
            }
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static func parseMailbox(_ text: String) -> (name: String?, address: String)? {
        var name: String?
        var address: String
        if let open = text.lastIndex(of: "<"), let close = text.lastIndex(of: ">"), open < close {
            address = String(text[text.index(after: open)..<close])
            var display = String(text[text.startIndex..<open]).trimmingCharacters(in: .whitespaces)
            if display.hasPrefix("\""), display.hasSuffix("\""), display.count >= 2 {
                display = unescape(String(display.dropFirst().dropLast()))
            }
            name = display.isEmpty ? nil : MIME.decodeEncodedWords(display)
        } else {
            address = text
            while let open = address.firstIndex(of: "("), let close = address.firstIndex(of: ")"), open < close {
                address.removeSubrange(open...close)
            }
        }
        address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty,
              !address.contains(where: { $0.isWhitespace || $0 == "<" || $0 == ">" || $0 == "," }) else { return nil }
        return (name, address)
    }

    private static func unescape(_ text: String) -> String {
        var result = ""
        var escaped = false
        for character in text {
            if escaped {
                result.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}

enum AddressEngine {
    static func email(_ entry: String) -> String {
        if let open = entry.lastIndex(of: "<"), let close = entry.lastIndex(of: ">"), open < close {
            return String(entry[entry.index(after: open)..<close]).lowercased()
        }
        return entry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum RecipientEngine {
    static func parse(_ raw: String?) -> [Participant] {
        AddressListParser.split(raw ?? "").enumerated().map { index, entry in
            let parts = PersonName.display(entry)
            return Participant(id: index, name: parts.name, address: parts.address.isEmpty ? entry : parts.address)
        }
    }

    static func format(_ people: [Participant]) -> String? {
        let entries = people.map { person -> String in
            guard !person.name.isEmpty else { return person.address }
            let quoted = person.name.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"" + quoted + "\" <" + person.address + ">"
        }
        return entries.isEmpty ? nil : entries.joined(separator: ", ")
    }

    static func summary(_ people: [Participant]) -> String {
        guard let first = people.first else { return "" }
        if people.count > NameLimit.recipientsInline { return first.first }
        return people.map { $0.name.isEmpty ? PersonName.middle($0.address, limit: NameLimit.summary) : $0.name }
            .joined(separator: ", ")
    }
}

enum SenderEngine {
    static func merged(account: String, chosen: String, profile: String, stored: [Participant]) -> [Participant] {
        let own = account.lowercased()
        let named = chosen.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        let primary = stored.first { $0.address.lowercased() == own }
        var result: [Participant] = []
        var seen: Set<String> = []
        func add(name: String, address: String) {
            let key = address.lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { return }
            result.append(Participant(id: result.count, name: named.isEmpty ? name : named, address: address))
        }
        let primaryName = primary.map(\.name).flatMap { $0.isEmpty ? nil : $0 } ?? fallback
        add(name: primaryName, address: account)
        for entry in stored { add(name: entry.name.isEmpty ? primaryName : entry.name, address: entry.address) }
        return result
    }

    static func receiving(_ senders: [Participant], headers: [String]) -> Participant? {
        let addresses = headers.flatMap { AddressListParser.split($0) }.map(AddressEngine.email)
        for address in addresses {
            if let match = senders.first(where: { $0.address.lowercased() == address }) { return match }
        }
        return nil
    }
}

public enum PersonName {
    private static let ellipsis = "\u{2026}"

    public static func initials(_ name: String) -> String {
        Initials.from(name)
    }

    public static func middle(_ text: String, limit: Int) -> String {
        let letters = Array(text)
        guard letters.count > limit else { return text }
        let head = Int((Double(limit - 1) * NameLimit.middleHead).rounded(.up))
        let tail = limit - 1 - head
        return String(letters.prefix(head)) + ellipsis + String(letters.suffix(tail))
    }

    static func display(_ raw: String) -> (name: String, address: String) {
        let entry = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = entry.lastIndex(of: "<"), let close = entry.lastIndex(of: ">"), open < close else {
            return ("", entry)
        }
        var name = entry[entry.startIndex..<open].trimmingCharacters(in: .whitespaces)
        if name.hasPrefix("\""), name.hasSuffix("\""), name.count >= 2 { name = String(name.dropFirst().dropLast()) }
        if name.contains("@"), !name.contains(where: \.isWhitespace) { name = "" }
        return (name, String(entry[entry.index(after: open)..<close]))
    }
}

public enum NameLimit {
    static let person = 40
    static let chip = 30
    static let summary = 30
    static let sender = 40
    static let middleHead = 0.55
    static let personAddress = 44
    static let firstName = 24
    static let suggestionAddress = 40
    public static let recipientsInline = 2
}
