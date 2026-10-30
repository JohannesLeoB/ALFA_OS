import Foundation

struct HTMLTokenizer {
    private static let rawTextTags: Set<String> = ["style", "script", "textarea", "title"]
    private static let lessThan = UInt8(ascii: "<")
    private static let greaterThan = UInt8(ascii: ">")
    private static let slash = UInt8(ascii: "/")
    private static let equals = UInt8(ascii: "=")
    private static let doubleQuote = UInt8(ascii: "\"")
    private static let singleQuote = UInt8(ascii: "'")
    private static let bang = UInt8(ascii: "!")
    private static let question = UInt8(ascii: "?")

    private let bytes: [UInt8]
    private var index = 0
    private var tokens: [HTMLToken] = []

    private init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    static func tokens(_ html: String) -> [HTMLToken] {
        var scanner = HTMLTokenizer(bytes: Array(html.utf8))
        scanner.run()
        return scanner.tokens
    }

    private mutating func run() {
        var textStart = 0
        while index < bytes.count {
            guard bytes[index] == Self.lessThan, opensMarkup(at: index) else {
                index += 1
                continue
            }
            emitText(from: textStart, to: index)
            readMarkup()
            textStart = index
        }
        emitText(from: textStart, to: bytes.count)
    }

    private func opensMarkup(at position: Int) -> Bool {
        guard position + 1 < bytes.count else { return false }
        let next = bytes[position + 1]
        return Self.isLetter(next) || next == Self.slash && position + 2 < bytes.count && Self.isLetter(bytes[position + 2])
            || next == Self.bang || next == Self.question
    }

    private mutating func emitText(from start: Int, to end: Int) {
        guard end > start else { return }
        tokens.append(.text(String(decoding: bytes[start..<end], as: UTF8.self)))
    }

    private mutating func readMarkup() {
        let next = bytes[index + 1]
        if next == Self.bang || next == Self.question {
            skipDeclaration()
        } else if next == Self.slash {
            readEnd()
        } else {
            readStart()
        }
    }

    private mutating func skipDeclaration() {
        if matches("<!--", at: index) {
            index = find("-->", from: index + 4).map { $0 + 3 } ?? bytes.count
            return
        }
        index = (bytes[index...].firstIndex(of: Self.greaterThan)).map { $0 + 1 } ?? bytes.count
    }

    private mutating func readEnd() {
        let begin = index
        index += 2
        let nameStart = index
        while index < bytes.count, !Self.isSpace(bytes[index]), bytes[index] != Self.greaterThan, bytes[index] != Self.slash { index += 1 }
        let name = String(decoding: bytes[nameStart..<index], as: UTF8.self).lowercased()
        index = (bytes[index...].firstIndex(of: Self.greaterThan)).map { $0 + 1 } ?? bytes.count
        tokens.append(HTMLToken(kind: .end, name: name, attributes: [:], selfClosing: false,
                                raw: String(decoding: bytes[begin..<index], as: UTF8.self)))
    }

    private mutating func readStart() {
        let begin = index
        index += 1
        let nameStart = index
        while index < bytes.count, !Self.isSpace(bytes[index]), bytes[index] != Self.greaterThan, bytes[index] != Self.slash { index += 1 }
        let name = String(decoding: bytes[nameStart..<index], as: UTF8.self).lowercased()
        var attributes: [String: String] = [:]
        var selfClosing = false
        loop: while index < bytes.count {
            skipSpaces()
            guard index < bytes.count else { break }
            switch bytes[index] {
            case Self.greaterThan:
                index += 1
                break loop
            case Self.slash:
                selfClosing = true
                index += 1
            default:
                let attribute = readAttribute()
                if let attribute { attributes[attribute.name] = attribute.value }
                selfClosing = false
            }
        }
        tokens.append(HTMLToken(kind: .start, name: name, attributes: attributes, selfClosing: selfClosing,
                                raw: String(decoding: bytes[begin..<index], as: UTF8.self)))
        if Self.rawTextTags.contains(name), !selfClosing { readRawText(of: name) }
    }

    private mutating func readAttribute() -> (name: String, value: String)? {
        let nameStart = index
        while index < bytes.count, !Self.isSpace(bytes[index]), bytes[index] != Self.equals,
              bytes[index] != Self.greaterThan, bytes[index] != Self.slash { index += 1 }
        guard index > nameStart else {
            index += 1
            return nil
        }
        let name = String(decoding: bytes[nameStart..<index], as: UTF8.self).lowercased()
        skipSpaces()
        guard index < bytes.count, bytes[index] == Self.equals else { return (name, "") }
        index += 1
        skipSpaces()
        guard index < bytes.count else { return (name, "") }
        let quote = bytes[index]
        if quote == Self.doubleQuote || quote == Self.singleQuote {
            index += 1
            let valueStart = index
            while index < bytes.count, bytes[index] != quote { index += 1 }
            let value = String(decoding: bytes[valueStart..<index], as: UTF8.self)
            if index < bytes.count { index += 1 }
            return (name, value)
        }
        let valueStart = index
        while index < bytes.count, !Self.isSpace(bytes[index]), bytes[index] != Self.greaterThan { index += 1 }
        return (name, String(decoding: bytes[valueStart..<index], as: UTF8.self))
    }

    private mutating func readRawText(of name: String) {
        let start = index
        let close = find("</" + name, from: index, ignoringCase: true) ?? bytes.count
        if close > start { tokens.append(.text(String(decoding: bytes[start..<close], as: UTF8.self), kind: .raw)) }
        index = close
    }

    private mutating func skipSpaces() {
        while index < bytes.count, Self.isSpace(bytes[index]) { index += 1 }
    }

    private func matches(_ pattern: String, at position: Int) -> Bool {
        let needle = Array(pattern.utf8)
        guard position + needle.count <= bytes.count else { return false }
        return Array(bytes[position..<(position + needle.count)]) == needle
    }

    private func find(_ pattern: String, from start: Int, ignoringCase: Bool = false) -> Int? {
        let needle = Array((ignoringCase ? pattern.lowercased() : pattern).utf8)
        guard !needle.isEmpty, bytes.count >= needle.count, start <= bytes.count - needle.count else { return nil }
        var position = start
        while position <= bytes.count - needle.count {
            var hit = true
            for offset in 0..<needle.count {
                let byte = ignoringCase ? Self.lower(bytes[position + offset]) : bytes[position + offset]
                if byte != needle[offset] {
                    hit = false
                    break
                }
            }
            if hit { return position }
            position += 1
        }
        return nil
    }

    private static func isLetter(_ byte: UInt8) -> Bool {
        (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
    }

    private static func isSpace(_ byte: UInt8) -> Bool {
        byte == 32 || byte == 9 || byte == 10 || byte == 13 || byte == 12
    }

    private static func lower(_ byte: UInt8) -> UInt8 {
        byte >= 65 && byte <= 90 ? byte + 32 : byte
    }
}
