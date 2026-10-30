import Foundation

actor SMTPSession {
    private static let implicitPort = 465
    private static let explicitPort = 587
    private static let plainPort = 25
    private static let replyLimit = 200
    private static let identity = "localhost"

    private let reader: StreamBuffer
    private(set) var extensions: [String] = []

    private init(reader: StreamBuffer) {
        self.reader = reader
    }

    static func open(settings: ServerSettings, opener: StreamOpener = StreamRouter.open) async throws -> SMTPSession {
        let fallback = settings.security == .ssl ? implicitPort : (settings.security == .starttls ? explicitPort : plainPort)
        let stream = try await opener(settings.host, settings.port ?? fallback, settings.security)
        let session = SMTPSession(reader: StreamBuffer(stream: stream))
        do {
            try await session.handshake(security: settings.security)
        } catch {
            await session.close()
            throw error
        }
        return session
    }

    private func handshake(security: TransportSecurity) async throws {
        _ = try expect(try await readReply(), [220])
        try await greet()
        if security == .starttls {
            guard extensions.contains(where: { $0.uppercased() == "STARTTLS" }) else { throw MailFailure.tlsUnavailable }
            _ = try await command("STARTTLS", expect: [220])
            try await reader.upgradeToTLS()
            try await greet()
        }
    }

    private func greet() async throws {
        let reply = try await command(Self.line("EHLO", Self.identity), expect: [])
        if reply.code == 250 {
            extensions = Array(reply.lines.dropFirst())
            return
        }
        _ = try await command(Self.line("HELO", Self.identity), expect: [250])
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

    func authenticate(user: String, secret: String) async throws {
        try await authenticate(user: user, credential: .password(secret))
    }

    func authenticate(user: String, credential: MailCredential) async throws {
        let mechanisms = authMechanisms
        switch credential {
        case .accessToken(let token): try await authenticateOAuth(user: user, token: token, mechanisms: mechanisms)
        case .password(let secret): try await authenticate(user: user, secret: secret, mechanisms: mechanisms)
        }
    }

    private func authenticateOAuth(user: String, token: String, mechanisms: Set<String>) async throws {
        guard mechanisms.contains(XOAuth2Engine.mechanism) else {
            throw MailFailure.unsupportedAuthentication(mechanisms.sorted().joined(separator: " "))
        }
        let payload = XOAuth2Engine.initialResponse(user: user, token: token)
        var reply = try await command(Self.line("AUTH", XOAuth2Engine.mechanism, payload), expect: [])
        if reply.code == 334 { reply = try await command("", expect: []) }
        try ensureAuthenticated(reply)
    }

    private func authenticate(user: String, secret: String, mechanisms: Set<String>) async throws {
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
            throw MailFailure.unsupportedAuthentication(mechanisms.sorted().joined(separator: " "))
        }
    }

    private func ensureAuthenticated(_ reply: SMTPReply) throws {
        guard reply.code == 235 else { throw MailFailure.authenticationRejected("\(reply.code) \(reply.text)") }
    }

    var declaredSize: Int? {
        for line in extensions {
            let words = line.uppercased().split(separator: " ")
            if words.count == 2, words[0] == "SIZE", let size = Int(words[1]), size > 0 { return size }
        }
        return nil
    }

    func send(from sender: String, recipients: [String], message: Data) async throws {
        if let limit = declaredSize, message.count > limit {
            throw MailFailure.smtpRejected(552, "5.3.4 Message size exceeds the server limit of \(limit) bytes")
        }
        _ = try await command(Self.line("MAIL", "FROM:<\(sender)>"), expect: [250])
        for recipient in recipients {
            let reply = try await command(Self.line("RCPT", "TO:<\(recipient)>"), expect: [])
            guard reply.code == 250 || reply.code == 251 else {
                _ = try? await command("RSET", expect: [])
                throw MailFailure.recipientRejected(recipient, reply.code, reply.text)
            }
        }
        _ = try await command("DATA", expect: [354])
        try await reader.write(SMTPDotStuffing.apply(message))
        _ = try expect(try await readReply(), [250])
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
            let line = MIME.string(from: raw, charset: nil)
            lines.append(line)
            if try SMTPReply.parseLine(line).isLast { break }
            if lines.count > Self.replyLimit { throw MailFailure.malformedResponse("smtpReplyLength") }
        }
        return try SMTPReply.assemble(lines)
    }

    private func expect(_ reply: SMTPReply, _ codes: Set<Int>) throws -> SMTPReply {
        guard codes.isEmpty || codes.contains(reply.code) else { throw MailFailure.smtpRejected(reply.code, reply.text) }
        return reply
    }

    private static func line(_ words: String...) -> String {
        words.joined(separator: " ")
    }

    private func command(_ line: String, expect codes: Set<Int>) async throws -> SMTPReply {
        guard !line.contains("\r"), !line.contains("\n") else {
            throw MailFailure.malformedResponse("smtpCommand")
        }
        try await reader.write(Data((line + "\r\n").utf8))
        return try expect(try await readReply(), codes)
    }
}
