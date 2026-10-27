import Foundation

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
