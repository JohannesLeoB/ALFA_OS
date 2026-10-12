import Foundation

indirect enum IMAPValue: Equatable, Sendable {
    case null
    case atom(String)
    case number(Int)
    case bytes(Data)
    case list([IMAPValue])

    var string: String? {
        switch self {
        case .atom(let text): text
        case .number(let number): String(number)
        case .bytes(let data): MailMIME.string(from: data, charset: nil)
        case .null, .list: nil
        }
    }

    var data: Data? {
        switch self {
        case .bytes(let data): data
        case .atom(let text): Data(text.utf8)
        case .number(let number): Data(String(number).utf8)
        case .null, .list: nil
        }
    }

    var int: Int? {
        switch self {
        case .number(let number): number
        case .atom(let text): Int(text)
        default: nil
        }
    }

    var items: [IMAPValue]? {
        if case .list(let items) = self { return items }
        return nil
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

enum IMAPStatus: String, Sendable {
    case ok = "OK"
    case no = "NO"
    case bad = "BAD"
    case preauth = "PREAUTH"
    case bye = "BYE"
}

struct IMAPResponseCode: Equatable, Sendable {
    var name: String
    var values: [IMAPValue]
}

enum IMAPResponse: Equatable, Sendable {
    case tagged(tag: String, status: IMAPStatus, code: IMAPResponseCode?, text: String)
    case status(IMAPStatus, code: IMAPResponseCode?, text: String)
    case data([IMAPValue])
    case continuation(String)
}

struct IMAPScanner {
    private let bytes: [UInt8]
    private(set) var index = 0
    var insideCode = false

    init(_ data: Data) {
        bytes = [UInt8](data)
    }

    var atEnd: Bool { index >= bytes.count }

    var peek: UInt8? { index < bytes.count ? bytes[index] : nil }

    mutating func skipSpaces() {
        while index < bytes.count, bytes[index] == 32 { index += 1 }
    }

    mutating func advance() {
        index += 1
    }

    mutating func rest() -> String {
        let slice = bytes[min(index, bytes.count)...]
        index = bytes.count
        return MailMIME.string(from: Data(slice), charset: nil).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func value() throws -> IMAPValue {
        skipSpaces()
        guard let byte = peek else { throw MailTransportError.malformedResponse("end") }
        switch byte {
        case 40: return .list(try list())
        case 34: return .bytes(try quoted())
        case 123: return .bytes(try literal())
        default: return try atom()
        }
    }

    mutating func list() throws -> [IMAPValue] {
        guard peek == 40 else { throw MailTransportError.malformedResponse("list") }
        index += 1
        var items: [IMAPValue] = []
        while true {
            skipSpaces()
            guard let byte = peek else { throw MailTransportError.malformedResponse("listEnd") }
            if byte == 41 {
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
            if byte == 92, index + 1 < bytes.count {
                out.append(bytes[index + 1])
                index += 2
            } else if byte == 34 {
                index += 1
                return Data(out)
            } else {
                out.append(byte)
                index += 1
            }
        }
        throw MailTransportError.malformedResponse("quoted")
    }

    mutating func literal() throws -> Data {
        index += 1
        var digits = ""
        while index < bytes.count, bytes[index] >= 48, bytes[index] <= 57 {
            digits.append(Character(UnicodeScalar(bytes[index])))
            index += 1
        }
        if index < bytes.count, bytes[index] == 43 { index += 1 }
        guard index < bytes.count, bytes[index] == 125, let size = Int(digits) else {
            throw MailTransportError.malformedResponse("literal")
        }
        index += 1
        guard index + 1 < bytes.count, bytes[index] == 13, bytes[index + 1] == 10 else {
            throw MailTransportError.malformedResponse("literal")
        }
        index += 2
        guard size >= 0, index + size <= bytes.count else { throw MailTransportError.malformedResponse("literalSize") }
        let data = Data(bytes[index..<(index + size)])
        index += size
        return data
    }

    mutating func atom() throws -> IMAPValue {
        let start = index
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 32 || byte == 40 || byte == 41 || byte == 13 || byte == 10 { break }
            if insideCode && byte == 93 { break }
            if byte == 91 && insideCode == false {
                while index < bytes.count, bytes[index] != 93 { index += 1 }
                if index < bytes.count { index += 1 }
                continue
            }
            index += 1
        }
        guard index > start else { throw MailTransportError.malformedResponse("atom") }
        let text = String(decoding: bytes[start..<index], as: UTF8.self)
        if text.uppercased() == "NIL" { return .null }
        if text.count <= 10, text.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(text) { return .number(number) }
        return .atom(text)
    }
}

enum IMAPResponseParser {
    static func parse(_ data: Data) throws -> IMAPResponse {
        var scanner = IMAPScanner(data)
        guard let first = scanner.peek else { throw MailTransportError.malformedResponse("empty") }
        if first == 43 {
            scanner.advance()
            return .continuation(scanner.rest())
        }
        if first == 42 {
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
        guard case .atom(let tag) = try scanner.atom() else { throw MailTransportError.malformedResponse("tag") }
        scanner.skipSpaces()
        guard case .atom(let word) = try scanner.atom(), let status = IMAPStatus(rawValue: word.uppercased()) else {
            throw MailTransportError.malformedResponse("status")
        }
        let (code, text) = try statusBody(&scanner)
        return .tagged(tag: tag, status: status, code: code, text: text)
    }

    private static func statusBody(_ scanner: inout IMAPScanner) throws -> (IMAPResponseCode?, String) {
        scanner.skipSpaces()
        guard scanner.peek == 91 else { return (nil, scanner.rest()) }
        scanner.advance()
        scanner.insideCode = true
        defer { scanner.insideCode = false }
        guard case .atom(let name) = try scanner.atom() else { throw MailTransportError.malformedResponse("code") }
        var values: [IMAPValue] = []
        while true {
            scanner.skipSpaces()
            guard let byte = scanner.peek else { throw MailTransportError.malformedResponse("codeEnd") }
            if byte == 93 {
                scanner.advance()
                break
            }
            values.append(try scanner.value())
        }
        scanner.insideCode = false
        return (IMAPResponseCode(name: name.uppercased(), values: values), scanner.rest())
    }

    static func literalSize(endingLine line: Data) -> Int? {
        guard line.last == 125, let open = line.lastIndex(of: 123) else { return nil }
        var digits = line[(open + 1)..<(line.endIndex - 1)]
        if digits.last == 43 { digits = digits.dropLast() }
        guard digits.isEmpty == false, digits.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
        return Int(String(decoding: digits, as: UTF8.self))
    }
}

enum IMAPModifiedUTF7 {
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
            guard pending.isEmpty == false else { return }
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
