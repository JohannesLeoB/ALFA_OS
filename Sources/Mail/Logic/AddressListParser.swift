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
