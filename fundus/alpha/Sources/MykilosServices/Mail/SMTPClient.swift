import Foundation
import MykilosKit

struct SMTPReply: Equatable, Sendable {
    var code: Int
    var lines: [String]

    var text: String { lines.joined(separator: "\n") }

    static func parseLine(_ line: String) throws -> (code: Int, isLast: Bool, text: String) {
        let characters = Array(line)
        guard characters.count >= 3, let code = Int(String(characters[0..<3])), code >= 100, code <= 599 else {
            throw MailTransportError.malformedResponse("smtpReply")
        }
        if characters.count == 3 { return (code, true, "") }
        let separator = characters[3]
        guard separator == " " || separator == "-" else { throw MailTransportError.malformedResponse("smtpReply") }
        return (code, separator == " ", String(characters[4...]))
    }

    static func assemble(_ lines: [String]) throws -> SMTPReply {
        var code: Int?
        var texts: [String] = []
        for line in lines {
            let parsed = try parseLine(line)
            if let code, code != parsed.code { throw MailTransportError.malformedResponse("smtpReplyCode") }
            code = parsed.code
            texts.append(parsed.text)
        }
        guard let code else { throw MailTransportError.malformedResponse("smtpReply") }
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
            lineStart = previous == 13 && byte == 10
            previous = byte
        }
        if out.suffix(2) != Data([13, 10]) { out.append(contentsOf: [13, 10]) }
        out.append(contentsOf: [46, 13, 10])
        return out
    }
}

actor SMTPSession {
    private let reader: MailReader
    private(set) var extensions: [String] = []

    private init(reader: MailReader) {
        self.reader = reader
    }

    static func open(settings: MailServerSettings) async throws -> SMTPSession {
        let port = settings.port ?? (settings.security == .ssl ? 465 : (settings.security == .starttls ? 587 : 25))
        let stream = try await MailStreams.open(host: settings.host, port: port, security: settings.security)
        let session = SMTPSession(reader: MailReader(stream: stream))
        do {
            try await session.handshake(security: settings.security)
        } catch {
            await session.close()
            throw error
        }
        return session
    }

    private func handshake(security: MailSecurity) async throws {
        _ = try await expect(try await readReply(), [220])
        try await greet()
        if security == .starttls {
            guard extensions.contains(where: { $0.uppercased() == "STARTTLS" }) else { throw MailTransportError.tlsUnavailable }
            _ = try await command("STARTTLS", expect: [220])
            try await reader.upgradeToTLS()
            try await greet()
        }
    }

    private func greet() async throws {
        let reply = try await command(Self.line("EHLO", "localhost"), expect: [])
        if reply.code == 250 {
            extensions = Array(reply.lines.dropFirst())
            return
        }
        _ = try await command(Self.line("HELO", "localhost"), expect: [250])
        extensions = []
    }

    private var authMechanisms: Set<String> {
        var mechanisms = Set<String>()
        for line in extensions {
            let upper = line.uppercased()
            if upper.hasPrefix("AUTH ") || upper.hasPrefix("AUTH=") {
                let body = upper.dropFirst(5).replacingOccurrences(of: "=", with: " ")
                mechanisms.formUnion(body.split(separator: " ").map(String.init))
            }
        }
        return mechanisms
    }

    func authenticate(_ credential: MailCredential) async throws {
        let mechanisms = authMechanisms
        switch credential {
        case .oauth(let user, let token):
            guard mechanisms.contains("XOAUTH2") else { throw MailTransportError.unsupportedAuthentication("XOAUTH2") }
            let payload = Data("user=\(user)\u{01}auth=Bearer \(token)\u{01}\u{01}".utf8).base64EncodedString()
            var reply = try await command(Self.line("AUTH", "XOAUTH2", payload), expect: [])
            if reply.code == 334 { reply = try await command("", expect: []) }
            try ensureAuthenticated(reply)
        case .password(let user, let secret):
            if mechanisms.contains("PLAIN") {
                let payload = Data("\0\(user)\0\(secret)".utf8).base64EncodedString()
                try ensureAuthenticated(try await command(Self.line("AUTH", "PLAIN", payload), expect: []))
            } else if mechanisms.contains("LOGIN") {
                var reply = try await command(Self.line("AUTH", "LOGIN"), expect: [])
                guard reply.code == 334 else { return try ensureAuthenticated(reply) }
                reply = try await command(Data(user.utf8).base64EncodedString(), expect: [])
                guard reply.code == 334 else { return try ensureAuthenticated(reply) }
                try ensureAuthenticated(try await command(Data(secret.utf8).base64EncodedString(), expect: []))
            } else {
                throw MailTransportError.unsupportedAuthentication(mechanisms.sorted().joined(separator: " "))
            }
        }
    }

    private func ensureAuthenticated(_ reply: SMTPReply) throws {
        guard reply.code == 235 else { throw MailTransportError.authenticationRejected("\(reply.code) \(reply.text)") }
    }

    func send(from sender: String, recipients: [String], message: Data) async throws {
        _ = try await command(Self.line("MAIL", "FROM:<\(sender)>"), expect: [250])
        for recipient in recipients {
            let reply = try await command(Self.line("RCPT", "TO:<\(recipient)>"), expect: [])
            guard reply.code == 250 || reply.code == 251 else {
                _ = try? await command("RSET", expect: [])
                throw MailTransportError.recipientRejected(recipient, reply.code, reply.text)
            }
        }
        _ = try await command("DATA", expect: [354])
        try await reader.write(SMTPDotStuffing.apply(message))
        _ = try await expect(try await readReply(), [250])
    }

    func quit() async {
        _ = try? await command("QUIT", expect: [])
        await close()
    }

    func close() async {
        await reader.close()
    }

    private func readReply() async throws -> SMTPReply {
        var lines: [String] = []
        while true {
            let raw = try await reader.readLine()
            let line = MailMIME.string(from: raw, charset: nil)
            lines.append(line)
            if try SMTPReply.parseLine(line).isLast { break }
            if lines.count > 200 { throw MailTransportError.malformedResponse("smtpReplyLength") }
        }
        return try SMTPReply.assemble(lines)
    }

    private func expect(_ reply: SMTPReply, _ codes: Set<Int>) throws -> SMTPReply {
        guard codes.isEmpty || codes.contains(reply.code) else { throw MailTransportError.smtpRejected(reply.code, reply.text) }
        return reply
    }

    private static func line(_ words: String...) -> String {
        words.joined(separator: " ")
    }

    private func command(_ line: String, expect codes: Set<Int>) async throws -> SMTPReply {
        guard line.contains("\r") == false, line.contains("\n") == false else {
            throw MailTransportError.malformedResponse("smtpCommand")
        }
        try await reader.write(Data((line + "\r\n").utf8))
        return try expect(try await readReply(), codes)
    }
}
