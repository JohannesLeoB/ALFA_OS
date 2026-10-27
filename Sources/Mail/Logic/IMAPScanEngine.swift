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
