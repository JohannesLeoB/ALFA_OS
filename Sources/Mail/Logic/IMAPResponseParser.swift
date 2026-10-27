import Foundation

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
