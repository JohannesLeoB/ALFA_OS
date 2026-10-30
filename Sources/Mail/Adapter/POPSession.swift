import Foundation

actor POPSession {
    private static let implicitPort = 995
    private static let explicitPort = 110
    private static let lineLimit = 2_000_000

    private let reader: StreamBuffer
    private(set) var capabilities: [String] = []

    private init(reader: StreamBuffer) {
        self.reader = reader
    }

    static func open(settings: ServerSettings, opener: StreamOpener = StreamRouter.open) async throws -> POPSession {
        guard settings.security != .none else { throw MailFailure.tlsUnavailable }
        let port = settings.port ?? (settings.security == .ssl ? implicitPort : explicitPort)
        let stream = try await opener(settings.host, port, settings.security)
        let session = POPSession(reader: StreamBuffer(stream: stream))
        do {
            _ = try await session.status()
            try await session.loadCapabilities()
            if settings.security == .starttls {
                guard await session.capabilities.contains(where: { $0.uppercased() == "STLS" }) else {
                    throw MailFailure.tlsUnavailable
                }
                _ = try await session.command("STLS")
                try await session.reader.upgradeToTLS()
                try await session.loadCapabilities()
            }
        } catch {
            await session.close()
            throw error
        }
        return session
    }

    func authenticate(user: String, secret: String) async throws {
        let sasl = capabilities.first { $0.uppercased().hasPrefix("SASL ") }?.uppercased().split(separator: " ") ?? []
        do {
            if sasl.contains("PLAIN") {
                _ = try await command("AUTH PLAIN " + Data("\0\(user)\0\(secret)".utf8).base64EncodedString())
            } else {
                _ = try await command("USER " + user)
                _ = try await command("PASS " + secret)
            }
        } catch MailFailure.serverRejected(let text) {
            throw MailFailure.authenticationRejected(text)
        }
    }

    func identifiers() async throws -> [(number: Int, uid: String)] {
        _ = try await command("UIDL")
        return try await multiline().compactMap { line in
            let words = MIME.string(from: line, charset: nil).split(separator: " ")
            guard words.count >= 2, let number = Int(words[0]) else { return nil }
            return (number, String(words[1]))
        }
    }

    func top(_ number: Int, lines: Int) async throws -> Data {
        _ = try await command("TOP \(number) \(lines)")
        return Self.joined(try await multiline())
    }

    func retrieve(_ number: Int) async throws -> Data {
        _ = try await command("RETR \(number)")
        return Self.joined(try await multiline())
    }

    func delete(_ number: Int) async throws {
        _ = try await command("DELE \(number)")
    }

    func quit() async {
        _ = try? await command("QUIT")
        await close()
    }

    func close() async {
        await reader.close()
    }

    private func loadCapabilities() async throws {
        do {
            _ = try await command("CAPA")
            capabilities = try await multiline().map { MIME.string(from: $0, charset: nil) }
        } catch MailFailure.serverRejected {
            capabilities = []
        }
    }

    private func command(_ line: String) async throws -> String {
        guard !line.contains("\r"), !line.contains("\n") else { throw MailFailure.malformedResponse("popCommand") }
        try await reader.write(Data((line + "\r\n").utf8))
        return try await status()
    }

    private func status() async throws -> String {
        let line = MIME.string(from: try await reader.readLine(), charset: nil)
        if line.hasPrefix("+OK") { return String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
        if line.hasPrefix("-ERR") { throw MailFailure.serverRejected(String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)) }
        throw MailFailure.malformedResponse("popStatus")
    }

    private func multiline() async throws -> [Data] {
        var lines: [Data] = []
        while true {
            var line = try await reader.readLine()
            if line == Data([46]) { return lines }
            if line.first == 46 { line = line.dropFirst() }
            lines.append(Data(line))
            if lines.count > Self.lineLimit { throw MailFailure.malformedResponse("popLength") }
        }
    }

    static func joined(_ lines: [Data]) -> Data {
        var data = Data()
        for line in lines {
            data.append(line)
            data.append(contentsOf: [13, 10])
        }
        return data
    }
}
