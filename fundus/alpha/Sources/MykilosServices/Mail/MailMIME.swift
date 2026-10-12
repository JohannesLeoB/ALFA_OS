import Foundation

struct MailHeaderField: Equatable, Sendable {
    var name: String
    var value: String
}

struct MailParameterizedValue: Equatable, Sendable {
    var value: String
    var parameters: [String: String]
}

enum MailMIME {
    static func decodeBase64(_ data: Data) -> Data {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
        var filtered = data.filter { allowed.contains($0) }
        while filtered.count % 4 != 0 { filtered.append(61) }
        return Data(base64Encoded: filtered) ?? Data()
    }

    static func decodeQuotedPrintable(_ data: Data, header: Bool = false) -> Data {
        let bytes = [UInt8](data)
        var out = [UInt8]()
        out.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 61 {
                if index + 1 < bytes.count, bytes[index + 1] == 10 {
                    index += 2
                    continue
                }
                if index + 2 < bytes.count, bytes[index + 1] == 13, bytes[index + 2] == 10 {
                    index += 3
                    continue
                }
                if index + 2 < bytes.count, let high = hexValue(bytes[index + 1]), let low = hexValue(bytes[index + 2]) {
                    out.append(UInt8(high * 16 + low))
                    index += 3
                    continue
                }
                out.append(byte)
                index += 1
            } else if header && byte == 95 {
                out.append(32)
                index += 1
            } else {
                out.append(byte)
                index += 1
            }
        }
        return Data(out)
    }

    private static func hexValue(_ byte: UInt8) -> Int? {
        switch byte {
        case 48...57: Int(byte) - 48
        case 65...70: Int(byte) - 55
        case 97...102: Int(byte) - 87
        default: nil
        }
    }

    static func decodeTransfer(_ data: Data, encoding: String) -> Data {
        switch encoding.lowercased() {
        case "base64": decodeBase64(data)
        case "quoted-printable": decodeQuotedPrintable(data)
        default: data
        }
    }

    static func string(from data: Data, charset: String?) -> String {
        if let name = charset?.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")), name.isEmpty == false {
            let base = name.split(separator: "*", maxSplits: 1).first.map(String.init) ?? name
            let converted = CFStringConvertIANACharSetNameToEncoding(base as CFString)
            if converted != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(converted))
                if let text = String(data: data, encoding: encoding) { return text }
            }
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
    }

    private static let encodedWord = try? NSRegularExpression(pattern: "=\\?([^?\\s]+)\\?([BbQq])\\?([^?\\s]*)\\?=")

    static func decodeEncodedWords(_ text: String) -> String {
        guard text.contains("=?"), let regex = encodedWord else { return text }
        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard matches.isEmpty == false else { return text }
        var result = ""
        var cursor = 0
        var previousWasWord = false
        for match in matches {
            let gap = source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let gapIsBlank = gap.allSatisfy(\.isWhitespace)
            if (previousWasWord && gapIsBlank) == false { result += gap }
            let charset = source.substring(with: match.range(at: 1))
            let kind = source.substring(with: match.range(at: 2)).uppercased()
            let payload = Data(source.substring(with: match.range(at: 3)).utf8)
            let raw = kind == "B" ? decodeBase64(payload) : decodeQuotedPrintable(payload, header: true)
            result += string(from: raw, charset: charset)
            cursor = match.range.location + match.range.length
            previousWasWord = true
        }
        result += source.substring(from: cursor)
        return result
    }

    static func parseHeaders(_ data: Data) -> [MailHeaderField] {
        let text = string(from: data, charset: nil)
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var fields: [MailHeaderField] = []
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.isEmpty { break }
            if (line.first == " " || line.first == "\t"), fields.isEmpty == false {
                fields[fields.count - 1].value += " " + line.trimmingCharacters(in: .whitespaces)
            } else if let colon = line.firstIndex(of: ":") {
                let name = String(line[line.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                fields.append(MailHeaderField(name: name, value: value))
            }
        }
        return fields
    }

    static func parseParameterized(_ text: String) -> MailParameterizedValue {
        var parts: [String] = []
        var current = ""
        var quoted = false
        var escaped = false
        for character in text {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" && quoted {
                current.append(character)
                escaped = true
            } else if character == "\"" {
                quoted.toggle()
                current.append(character)
            } else if character == ";" && quoted == false {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        let value = (parts.first ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        var raw: [(String, String)] = []
        for part in parts.dropFirst() {
            guard let equals = part.firstIndex(of: "=") else { continue }
            let key = String(part[part.startIndex..<equals]).trimmingCharacters(in: .whitespaces).lowercased()
            var parameter = String(part[part.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
            if parameter.hasPrefix("\""), parameter.hasSuffix("\""), parameter.count >= 2 {
                parameter = unescapeQuoted(String(parameter.dropFirst().dropLast()))
            }
            raw.append((key, parameter))
        }
        return MailParameterizedValue(value: value, parameters: resolveExtended(raw))
    }

    private static func unescapeQuoted(_ text: String) -> String {
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

    static func resolveExtended(_ pairs: [(String, String)]) -> [String: String] {
        var plain: [String: String] = [:]
        var segments: [String: [(Int, String, Bool)]] = [:]
        for (key, value) in pairs {
            guard let star = key.firstIndex(of: "*") else {
                plain[key] = decodeEncodedWords(value)
                continue
            }
            let base = String(key[key.startIndex..<star])
            let suffix = String(key[key.index(after: star)...])
            if suffix.isEmpty {
                segments[base, default: []].append((0, value, true))
            } else if suffix.hasSuffix("*"), let number = Int(suffix.dropLast()) {
                segments[base, default: []].append((number, value, true))
            } else if let number = Int(suffix) {
                segments[base, default: []].append((number, value, false))
            }
        }
        for (base, list) in segments {
            let ordered = list.sorted { $0.0 < $1.0 }
            var charset: String?
            var joined = Data()
            for (offset, entry) in ordered.enumerated() {
                var piece = entry.1
                if entry.2 {
                    if offset == 0 {
                        let sections = piece.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
                        if sections.count == 3 {
                            charset = String(sections[0])
                            piece = String(sections[2])
                        }
                    }
                    joined.append(percentDecode(piece))
                } else {
                    joined.append(Data(piece.utf8))
                }
            }
            plain[base] = string(from: joined, charset: charset)
        }
        return plain
    }

    private static func percentDecode(_ text: String) -> Data {
        let bytes = [UInt8](text.utf8)
        var out = [UInt8]()
        var index = 0
        while index < bytes.count {
            if bytes[index] == 37, index + 2 < bytes.count,
               let high = hexValue(bytes[index + 1]), let low = hexValue(bytes[index + 2]) {
                out.append(UInt8(high * 16 + low))
                index += 3
            } else {
                out.append(bytes[index])
                index += 1
            }
        }
        return Data(out)
    }

    static func splitAddresses(_ text: String) -> [String] {
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
            case "<" where quoted == false && comment == 0:
                angle += 1
                current.append(character)
            case ">" where quoted == false && comment == 0:
                angle = max(0, angle - 1)
                current.append(character)
            case "(" where quoted == false:
                comment += 1
                current.append(character)
            case ")" where quoted == false:
                comment = max(0, comment - 1)
                current.append(character)
            case "," where quoted == false && angle == 0 && comment == 0, ";" where quoted == false && angle == 0 && comment == 0:
                result.append(current)
                current = ""
            default:
                current.append(character)
            }
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }
    }

    static func parseMailbox(_ text: String) -> (name: String?, address: String)? {
        var name: String?
        var address: String
        if let open = text.lastIndex(of: "<"), let close = text.lastIndex(of: ">"), open < close {
            address = String(text[text.index(after: open)..<close])
            var display = String(text[text.startIndex..<open]).trimmingCharacters(in: .whitespaces)
            if display.hasPrefix("\""), display.hasSuffix("\""), display.count >= 2 {
                display = unescapeQuoted(String(display.dropFirst().dropLast()))
            }
            name = display.isEmpty ? nil : decodeEncodedWords(display)
        } else {
            address = text
            while let open = address.firstIndex(of: "("), let close = address.firstIndex(of: ")"), open < close {
                address.removeSubrange(open...close)
            }
        }
        address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].isEmpty == false, parts[1].isEmpty == false,
              address.contains(where: { $0.isWhitespace || $0 == "<" || $0 == ">" || $0 == "," }) == false else { return nil }
        return (name, address)
    }

    private static func formatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = pattern
        return formatter
    }

    static func parseMessageDate(_ text: String) -> Date? {
        var value = text
        while let open = value.firstIndex(of: "("), let close = value.lastIndex(of: ")"), open < close {
            value.removeSubrange(open...close)
        }
        value = value.trimmingCharacters(in: .whitespaces)
        for zone in ["GMT", "UTC", "UT", "Z"] where value.hasSuffix(" " + zone) {
            value = String(value.dropLast(zone.count)) + "+0000"
        }
        let patterns = [["EEE,", "d", "MMM", "yyyy", "HH:mm:ss", "Z"], ["d", "MMM", "yyyy", "HH:mm:ss", "Z"],
                        ["EEE,", "d", "MMM", "yyyy", "HH:mm", "Z"], ["d", "MMM", "yyyy", "HH:mm", "Z"]]
        for pattern in patterns {
            if let date = formatter(pattern.joined(separator: " ")).date(from: value) { return date }
        }
        return nil
    }

    static func parseInternalDate(_ text: String) -> Date? {
        formatter("d-MMM-yyyy HH:mm:ss Z").date(from: text.trimmingCharacters(in: .whitespaces))
    }

    static func formatMessageDate(_ date: Date) -> String {
        formatter(["EEE,", "dd", "MMM", "yyyy", "HH:mm:ss", "Z"].joined(separator: " ")).string(from: date)
    }
}
