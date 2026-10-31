import Foundation

enum Byte {
    static let lineFeed: UInt8 = 10
    static let carriageReturn: UInt8 = 13
    static let space: UInt8 = 32
    static let quote: UInt8 = 34
    static let asterisk: UInt8 = 42
    static let plus: UInt8 = 43
    static let zero: UInt8 = 48
    static let nine: UInt8 = 57
    static let openParen: UInt8 = 40
    static let closeParen: UInt8 = 41
    static let backslash: UInt8 = 92
    static let openBracket: UInt8 = 91
    static let closeBracket: UInt8 = 93
    static let openBrace: UInt8 = 123
    static let closeBrace: UInt8 = 125
}

struct IMAPScanEngine {
    private let bytes: [UInt8]
    private(set) var index = 0
    var insideCode = false

    init(_ data: Data) {
        bytes = [UInt8](data)
    }

    var atEnd: Bool { index >= bytes.count }

    var peek: UInt8? { index < bytes.count ? bytes[index] : nil }

    mutating func skipSpaces() {
        while index < bytes.count, bytes[index] == Byte.space { index += 1 }
    }

    mutating func advance() {
        index += 1
    }

    mutating func rest() -> String {
        let slice = bytes[min(index, bytes.count)...]
        index = bytes.count
        return MIME.string(from: Data(slice), charset: nil).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func value() throws -> IMAPValue {
        skipSpaces()
        guard let byte = peek else { throw MailFailure.malformedResponse("end") }
        switch byte {
        case Byte.openParen: return .list(try list())
        case Byte.quote: return .bytes(try quoted())
        case Byte.openBrace: return .bytes(try literal())
        default: return try atom()
        }
    }

    mutating func list() throws -> [IMAPValue] {
        guard peek == Byte.openParen else { throw MailFailure.malformedResponse("list") }
        index += 1
        var items: [IMAPValue] = []
        while true {
            skipSpaces()
            guard let byte = peek else { throw MailFailure.malformedResponse("listEnd") }
            if byte == Byte.closeParen {
                index += 1
                return items
            }
            items.append(try value())
        }
    }

    mutating func quoted() throws -> Data {
        index += 1
        var out = [UInt8]()
        while index < bytes.count {
            let byte = bytes[index]
            if byte == Byte.backslash, index + 1 < bytes.count {
                out.append(bytes[index + 1])
                index += 2
            } else if byte == Byte.quote {
                index += 1
                return Data(out)
            } else {
                out.append(byte)
                index += 1
            }
        }
        throw MailFailure.malformedResponse("quoted")
    }

    mutating func literal() throws -> Data {
        index += 1
        var digits = ""
        while index < bytes.count, bytes[index] >= Byte.zero, bytes[index] <= Byte.nine {
            digits.append(Character(UnicodeScalar(bytes[index])))
            index += 1
        }
        if index < bytes.count, bytes[index] == Byte.plus { index += 1 }
        guard index < bytes.count, bytes[index] == Byte.closeBrace, let size = Int(digits) else {
            throw MailFailure.malformedResponse("literal")
        }
        index += 1
        guard index + 1 < bytes.count, bytes[index] == Byte.carriageReturn, bytes[index + 1] == Byte.lineFeed else {
            throw MailFailure.malformedResponse("literal")
        }
        index += 2
        guard size >= 0, index + size <= bytes.count else { throw MailFailure.malformedResponse("literalSize") }
        let data = Data(bytes[index..<(index + size)])
        index += size
        return data
    }

    mutating func atom() throws -> IMAPValue {
        let start = index
        while index < bytes.count {
            let byte = bytes[index]
            if byte == Byte.space || byte == Byte.openParen || byte == Byte.closeParen || byte == Byte.carriageReturn
                || byte == Byte.lineFeed { break }
            if insideCode && byte == Byte.closeBracket { break }
            if byte == Byte.openBracket && !insideCode {
                while index < bytes.count, bytes[index] != Byte.closeBracket { index += 1 }
                if index < bytes.count { index += 1 }
                continue
            }
            index += 1
        }
        guard index > start else { throw MailFailure.malformedResponse("atom") }
        let text = String(decoding: bytes[start..<index], as: UTF8.self)
        if text.uppercased() == "NIL" { return .null }
        if text.count <= 10, text.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(text) { return .number(number) }
        return .atom(text)
    }
}

enum IMAPResponseParser {
    static func parse(_ data: Data) throws -> IMAPResponse {
        var scanner = IMAPScanEngine(data)
        guard let first = scanner.peek else { throw MailFailure.malformedResponse("empty") }
        if first == Byte.plus {
            scanner.advance()
            return .continuation(scanner.rest())
        }
        if first == Byte.asterisk {
            scanner.advance()
            scanner.skipSpaces()
            let word = try scanner.atom()
            if case .atom(let name) = word, let status = IMAPStatus(rawValue: name.uppercased()) {
                let (code, text) = try statusBody(&scanner)
                return .status(status, code: code, text: text)
            }
            var values = [word]
            while true {
                scanner.skipSpaces()
                if scanner.atEnd { break }
                values.append(try scanner.value())
            }
            return .data(values)
        }
        guard case .atom(let tag) = try scanner.atom() else { throw MailFailure.malformedResponse("tag") }
        scanner.skipSpaces()
        guard case .atom(let word) = try scanner.atom(), let status = IMAPStatus(rawValue: word.uppercased()) else {
            throw MailFailure.malformedResponse("status")
        }
        let (code, text) = try statusBody(&scanner)
        return .tagged(tag: tag, status: status, code: code, text: text)
    }

    private static func statusBody(_ scanner: inout IMAPScanEngine) throws -> (IMAPResponseCode?, String) {
        scanner.skipSpaces()
        guard scanner.peek == Byte.openBracket else { return (nil, scanner.rest()) }
        scanner.advance()
        scanner.insideCode = true
        defer { scanner.insideCode = false }
        guard case .atom(let name) = try scanner.atom() else { throw MailFailure.malformedResponse("code") }
        var values: [IMAPValue] = []
        while true {
            scanner.skipSpaces()
            guard let byte = scanner.peek else { throw MailFailure.malformedResponse("codeEnd") }
            if byte == Byte.closeBracket {
                scanner.advance()
                break
            }
            values.append(try scanner.value())
        }
        scanner.insideCode = false
        return (IMAPResponseCode(name: name.uppercased(), values: values), scanner.rest())
    }

    static func literalSize(endingLine line: Data) -> Int? {
        guard line.last == Byte.closeBrace, let open = line.lastIndex(of: Byte.openBrace) else { return nil }
        var digits = line[(open + 1)..<(line.endIndex - 1)]
        if digits.last == Byte.plus { digits = digits.dropLast() }
        guard !digits.isEmpty, digits.allSatisfy({ $0 >= Byte.zero && $0 <= Byte.nine }) else { return nil }
        return Int(String(decoding: digits, as: UTF8.self))
    }
}

enum IMAPBodyStructureParser {
    private static let singlePartFields = 7

    static func parse(_ value: IMAPValue) throws -> IMAPBodyPart {
        guard let items = value.items else { throw MailFailure.malformedResponse("bodystructure") }
        return try node(items, section: items.first?.items != nil ? "" : "1")
    }

    private static func node(_ items: [IMAPValue], section: String) throws -> IMAPBodyPart {
        if items.first?.items != nil {
            var children: [IMAPBodyPart] = []
            var position = 0
            while position < items.count, let child = items[position].items {
                let childSection = section.isEmpty ? String(position + 1) : "\(section).\(position + 1)"
                children.append(try node(child, section: childSection))
                position += 1
            }
            let subtype = position < items.count ? (items[position].string ?? "").lowercased() : ""
            let parameters = position + 1 < items.count ? pairs(items[position + 1]) : [:]
            let (disposition, dispositionParameters) = dispositionFields(items, at: position + 2)
            return IMAPBodyPart(
                section: section, mediaType: "multipart", subtype: subtype, parameters: parameters, contentID: nil,
                encoding: "7bit", size: 0, disposition: disposition, dispositionParameters: dispositionParameters,
                children: children)
        }
        guard items.count >= singlePartFields else { throw MailFailure.malformedResponse("bodystructurePart") }
        let mediaType = (items[0].string ?? "").lowercased()
        let subtype = (items[1].string ?? "").lowercased()
        var position = singlePartFields
        var children: [IMAPBodyPart] = []
        if mediaType == "text" {
            position += 1
        } else if mediaType == "message", subtype == "rfc822" || subtype == "global" {
            if items.count > 9, let inner = items[8].items {
                let innerSection = inner.first?.items != nil ? section : "\(section).1"
                children = [try node(inner, section: innerSection)]
            }
            position += 3
        }
        let (disposition, dispositionParameters) = dispositionFields(items, at: position + 1)
        return IMAPBodyPart(
            section: section, mediaType: mediaType, subtype: subtype, parameters: pairs(items[2]),
            contentID: items[3].string?.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")),
            encoding: (items[5].string ?? "7bit").lowercased(), size: items[6].int ?? 0,
            disposition: disposition, dispositionParameters: dispositionParameters, children: children)
    }

    private static func dispositionFields(_ items: [IMAPValue], at index: Int) -> (String?, [String: String]) {
        guard index < items.count, let fields = items[index].items, !fields.isEmpty else { return (nil, [:]) }
        let name = fields[0].string?.lowercased()
        let parameters = fields.count > 1 ? pairs(fields[1]) : [:]
        return (name, parameters)
    }

    private static func pairs(_ value: IMAPValue) -> [String: String] {
        guard let items = value.items else { return [:] }
        var raw: [(String, String)] = []
        var position = 0
        while position + 1 < items.count {
            if let key = items[position].string, let text = items[position + 1].string {
                raw.append((key.lowercased(), text))
            }
            position += 2
        }
        return MIME.resolveExtended(raw)
    }
}

enum IMAPFolderNameCodec {
    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            guard character == "&" else {
                result.append(character)
                index = text.index(after: index)
                continue
            }
            guard let dash = text[index...].firstIndex(of: "-") else {
                result += text[index...]
                break
            }
            let body = text[text.index(after: index)..<dash]
            if body.isEmpty {
                result.append("&")
            } else {
                var base64 = body.replacingOccurrences(of: ",", with: "/")
                while base64.count % 4 != 0 { base64.append("=") }
                if let data = Data(base64Encoded: base64), let decoded = String(data: data, encoding: .utf16BigEndian) {
                    result += decoded
                } else {
                    result += text[index...dash]
                }
            }
            index = text.index(after: dash)
        }
        return result
    }

    static func encode(_ text: String) -> String {
        var result = ""
        var pending: [UInt16] = []
        func flush() {
            guard !pending.isEmpty else { return }
            var data = Data()
            for unit in pending {
                data.append(UInt8(unit >> 8))
                data.append(UInt8(unit & 0xFF))
            }
            let base64 = data.base64EncodedString()
                .replacingOccurrences(of: "/", with: ",")
                .replacingOccurrences(of: "=", with: "")
            result += "&" + base64 + "-"
            pending.removeAll()
        }
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x20 && scalar.value <= 0x7E {
                flush()
                if scalar == "&" { result += "&-" } else { result.unicodeScalars.append(scalar) }
            } else {
                pending.append(contentsOf: Array(String(scalar).utf16))
            }
        }
        flush()
        return result
    }
}

enum UIDSetEngine {
    static func text(_ uids: [Int]) -> String {
        let sorted = Array(Set(uids)).sorted()
        var parts: [String] = []
        var index = 0
        while index < sorted.count {
            var end = index
            while end + 1 < sorted.count, sorted[end + 1] == sorted[end] + 1 { end += 1 }
            parts.append(end == index ? String(sorted[index]) : "\(sorted[index]):\(sorted[end])")
            index = end + 1
        }
        return parts.joined(separator: ",")
    }
}

enum XOAuth2Engine {
    static let mechanism = "XOAUTH2"

    static func initialResponse(user: String, token: String) -> String {
        Data("user=\(user)\u{01}auth=Bearer \(token)\u{01}\u{01}".utf8).base64EncodedString()
    }
}

struct SMTPReply: Equatable, Sendable {
    private static let lowest = 100
    private static let highest = 599
    private static let codeLength = 3

    var code: Int
    var lines: [String]

    var text: String { lines.joined(separator: "\n") }

    static func parseLine(_ line: String) throws -> (code: Int, isLast: Bool, text: String) {
        let characters = Array(line)
        guard characters.count >= codeLength, let code = Int(String(characters[0..<codeLength])),
              code >= lowest, code <= highest else {
            throw MailFailure.malformedResponse("smtpReply")
        }
        if characters.count == codeLength { return (code, true, "") }
        let separator = characters[codeLength]
        guard separator == " " || separator == "-" else { throw MailFailure.malformedResponse("smtpReply") }
        return (code, separator == " ", String(characters[(codeLength + 1)...]))
    }

    static func assemble(_ lines: [String]) throws -> SMTPReply {
        var code: Int?
        var texts: [String] = []
        for line in lines {
            let parsed = try parseLine(line)
            if let code, code != parsed.code { throw MailFailure.malformedResponse("smtpReplyCode") }
            code = parsed.code
            texts.append(parsed.text)
        }
        guard let code else { throw MailFailure.malformedResponse("smtpReply") }
        return SMTPReply(code: code, lines: texts)
    }
}

enum SMTPDotStuffing {
    static func apply(_ message: Data) -> Data {
        var out = Data()
        out.reserveCapacity(message.count + 64)
        var lineStart = true
        var previous: UInt8 = 0
        for byte in message {
            if lineStart && byte == 46 { out.append(46) }
            out.append(byte)
            lineStart = previous == Byte.carriageReturn && byte == Byte.lineFeed
            previous = byte
        }
        if out.suffix(2) != Data([Byte.carriageReturn, Byte.lineFeed]) {
            out.append(contentsOf: [Byte.carriageReturn, Byte.lineFeed])
        }
        out.append(contentsOf: [46, Byte.carriageReturn, Byte.lineFeed])
        return out
    }
}

enum DateEngine {
    private static let messagePatterns = [
        ["EEE,", "d", "MMM", "yyyy", "HH:mm:ss", "Z"], ["d", "MMM", "yyyy", "HH:mm:ss", "Z"],
        ["EEE,", "d", "MMM", "yyyy", "HH:mm", "Z"], ["d", "MMM", "yyyy", "HH:mm", "Z"]
    ]
    private static let zones = ["GMT", "UTC", "UT", "Z"]

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
        for zone in zones where value.hasSuffix(" " + zone) {
            value = String(value.dropLast(zone.count)) + "+0000"
        }
        for pattern in messagePatterns {
            if let date = formatter(pattern.joined(separator: " ")).date(from: value) { return date }
        }
        return nil
    }

    static func parseInternalDate(_ text: String) -> Date? {
        formatter("d-MMM-yyyy HH:mm:ss Z").date(from: text.trimmingCharacters(in: .whitespaces))
    }

    static func formatSearchDate(_ date: Date) -> String {
        formatter("d-MMM-yyyy").string(from: date)
    }

    static func formatMessageDate(_ date: Date) -> String {
        formatter(["EEE,", "dd", "MMM", "yyyy", "HH:mm:ss", "Z"].joined(separator: " ")).string(from: date)
    }
}
