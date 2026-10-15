import Foundation
import MykilosKit

enum MailCredential: Sendable {
    case password(user: String, secret: String)
    case oauth(user: String, token: String)
}

enum IMAPArgument: Sendable {
    case raw(String)
    case string(String)
    case literal(Data)
}

struct IMAPCommandResult: Sendable {
    var untagged: [IMAPResponse]
    var code: IMAPResponseCode?
    var text: String
    var continuations: [String]

    var dataRows: [[IMAPValue]] {
        untagged.compactMap { if case .data(let values) = $0 { values } else { nil } }
    }
}

struct IMAPSelection: Equatable, Sendable {
    var exists: Int
    var uidValidity: Int
    var uidNext: Int?
}

actor IMAPSession {
    private let reader: MailReader
    private var tagCounter = 0
    private(set) var capabilities: Set<String> = []
    private var authenticated = false

    private init(reader: MailReader) {
        self.reader = reader
    }

    static func open(settings: MailServerSettings, opener: MailStreamOpener = MailStreams.open) async throws -> IMAPSession {
        let port = settings.port ?? (settings.security == .ssl ? 993 : 143)
        let stream = try await opener(settings.host, port, settings.security)
        let session = IMAPSession(reader: MailReader(stream: stream))
        do {
            try await session.handshake(security: settings.security)
        } catch {
            await session.close()
            throw error
        }
        return session
    }

    static func verbatim(_ status: IMAPStatus, _ code: IMAPResponseCode?, _ text: String) -> String {
        guard let code else { return "\(status.rawValue) \(text)" }
        return "\(status.rawValue) [\(code.name)] \(text)"
    }

    private func handshake(security: MailSecurity) async throws {
        let greeting = try await nextResponse()
        guard case .status(let status, let code, let text) = greeting else {
            throw MailTransportError.malformedResponse("greeting")
        }
        switch status {
        case .ok: break
        case .preauth: authenticated = true
        case .no, .bad, .bye: throw MailTransportError.serverRejected(Self.verbatim(status, code, text))
        }
        if let code, code.name == "CAPABILITY" {
            capabilities = Self.capabilitySet(code.values)
        } else {
            try await refreshCapabilities()
        }
        if security == .starttls {
            guard capabilities.contains("STARTTLS") else { throw MailTransportError.tlsUnavailable }
            _ = try await run([.raw("STARTTLS")])
            try await reader.upgradeToTLS()
            try await refreshCapabilities()
        }
    }

    private func refreshCapabilities() async throws {
        let result = try await run([.raw("CAPABILITY")])
        for row in result.dataRows where row.first?.string?.uppercased() == "CAPABILITY" {
            capabilities = Self.capabilitySet(Array(row.dropFirst()))
        }
    }

    private static func capabilitySet(_ values: [IMAPValue]) -> Set<String> {
        Set(values.compactMap { $0.string?.uppercased() })
    }

    func has(_ capability: String) -> Bool {
        capabilities.contains(capability.uppercased())
    }

    func authenticate(_ credential: MailCredential) async throws {
        guard authenticated == false else { return }
        do {
            switch credential {
            case .password(let user, let secret):
                if capabilities.contains("AUTH=PLAIN") {
                    let payload = Data("\0\(user)\0\(secret)".utf8).base64EncodedString()
                    _ = try await run([.raw("AUTHENTICATE"), .raw("PLAIN")], replies: [payload])
                } else if capabilities.contains("LOGINDISABLED") == false {
                    _ = try await run([.raw("LOGIN"), .string(user), .string(secret)])
                } else {
                    throw MailTransportError.unsupportedAuthentication("LOGINDISABLED")
                }
            case .oauth(let user, let token):
                guard capabilities.contains("AUTH=XOAUTH2") else {
                    throw MailTransportError.unsupportedAuthentication("XOAUTH2")
                }
                let payload = Data("user=\(user)\u{01}auth=Bearer \(token)\u{01}\u{01}".utf8).base64EncodedString()
                _ = try await run([.raw("AUTHENTICATE"), .raw("XOAUTH2")], replies: [payload, ""])
            }
        } catch MailTransportError.serverRejected(let text) {
            throw MailTransportError.authenticationRejected(text)
        }
        authenticated = true
        try await refreshCapabilities()
    }

    func listFolders() async throws -> [IMAPListEntry] {
        let result = try await run([.raw("LIST"), .string(""), .string("*")])
        return result.dataRows.compactMap(IMAPListEntry.parse)
    }

    func select(_ path: String, readOnly: Bool) async throws -> IMAPSelection {
        let result = try await run([.raw(readOnly ? "EXAMINE" : "SELECT"), .string(IMAPModifiedUTF7.encode(path))])
        var exists = 0
        var validity: Int?
        var next: Int?
        for response in result.untagged {
            switch response {
            case .data(let values):
                if values.count >= 2, values[1].string?.uppercased() == "EXISTS", let count = values[0].int { exists = count }
            case .status(_, let code?, _):
                if code.name == "UIDVALIDITY" { validity = code.values.first?.int }
                if code.name == "UIDNEXT" { next = code.values.first?.int }
            default:
                break
            }
        }
        guard let validity else { throw MailTransportError.malformedResponse("UIDVALIDITY") }
        return IMAPSelection(exists: exists, uidValidity: validity, uidNext: next)
    }

    func searchUIDs(_ criteria: [IMAPArgument]) async throws -> [Int] {
        let result = try await run([.raw("UID"), .raw("SEARCH")] + criteria)
        var found: [Int] = []
        for row in result.dataRows where row.first?.string?.uppercased() == "SEARCH" {
            found += row.dropFirst().compactMap(\.int)
        }
        return Array(Set(found)).sorted()
    }

    func fetch(uids: [Int], items: [String]) async throws -> [IMAPFetched] {
        guard uids.isEmpty == false else { return [] }
        let set = uids.map(String.init).joined(separator: ",")
        let result = try await run([.raw("UID"), .raw("FETCH"), .raw(set), .raw("(" + items.joined(separator: " ") + ")")])
        var merged: [Int: IMAPFetched] = [:]
        for row in result.dataRows {
            guard let fetched = try IMAPFetched.parse(row), let uid = fetched.uid else { continue }
            if var existing = merged[uid] {
                existing.flags = fetched.flags.isEmpty ? existing.flags : fetched.flags
                existing.internalDate = fetched.internalDate ?? existing.internalDate
                existing.size = fetched.size ?? existing.size
                existing.envelope = fetched.envelope ?? existing.envelope
                existing.structure = fetched.structure ?? existing.structure
                existing.sections.merge(fetched.sections) { _, new in new }
                merged[uid] = existing
            } else {
                merged[uid] = fetched
            }
        }
        return uids.compactMap { merged[$0] }
    }

    func fetchSection(uid: Int, section: String) async throws -> Data {
        guard let fetched = try await fetch(uids: [uid], items: ["UID", "BODY.PEEK[\(section)]"]).first,
              let data = fetched.sections[section.uppercased()] else {
            throw MailTransportError.messageNotFound(String(uid))
        }
        return data
    }

    func store(uid: Int, flags: [String], adding: Bool) async throws {
        guard flags.isEmpty == false else { return }
        let sign = adding ? "+" : "-"
        _ = try await run([.raw("UID"), .raw("STORE"), .raw(String(uid)), .raw(sign + "FLAGS.SILENT"),
                           .raw("(" + flags.joined(separator: " ") + ")")])
    }

    func copy(uid: Int, to path: String) async throws {
        _ = try await run([.raw("UID"), .raw("COPY"), .raw(String(uid)), .string(IMAPModifiedUTF7.encode(path))])
    }

    func move(uid: Int, to path: String) async throws {
        _ = try await run([.raw("UID"), .raw("MOVE"), .raw(String(uid)), .string(IMAPModifiedUTF7.encode(path))])
    }

    func append(to path: String, flags: [String], message: Data) async throws -> IMAPCommandResult {
        try await run([.raw("APPEND"), .string(IMAPModifiedUTF7.encode(path)),
                       .raw("(" + flags.joined(separator: " ") + ")"), .literal(message)])
    }

    func expunge(uid: Int) async throws {
        _ = try await run([.raw("UID"), .raw("EXPUNGE"), .raw(String(uid))])
    }

    func logout() async {
        _ = try? await run([.raw("LOGOUT")])
        await close()
    }

    func close() async {
        await reader.close()
    }

    private func nextTag() -> String {
        tagCounter += 1
        return String(format: "A%04d", tagCounter)
    }

    func nextResponse() async throws -> IMAPResponse {
        var assembled = try await reader.readLine()
        while let size = IMAPResponseParser.literalSize(endingLine: assembled) {
            assembled.append(contentsOf: [13, 10])
            assembled.append(try await reader.readBytes(size))
            assembled.append(try await reader.readLine())
        }
        return try IMAPResponseParser.parse(assembled)
    }

    func run(_ arguments: [IMAPArgument], replies: [String] = []) async throws -> IMAPCommandResult {
        let tag = nextTag()
        var untagged: [IMAPResponse] = []
        var continuations: [String] = []
        var pendingReplies = replies
        var line = Data(tag.utf8)
        for argument in arguments {
            line.append(32)
            switch argument {
            case .raw(let text):
                line.append(Data(text.utf8))
            case .literal(let payload):
                line.append(Data("{\(payload.count)}".utf8))
                line.append(contentsOf: [13, 10])
                try await reader.write(line)
                try await awaitContinuation(tag: tag, untagged: &untagged)
                line = payload
            case .string(let text):
                if let quoted = Self.quote(text) {
                    line.append(Data(quoted.utf8))
                } else {
                    let payload = Data(text.utf8)
                    line.append(Data("{\(payload.count)}".utf8))
                    line.append(contentsOf: [13, 10])
                    try await reader.write(line)
                    try await awaitContinuation(tag: tag, untagged: &untagged)
                    line = payload
                }
            }
        }
        line.append(contentsOf: [13, 10])
        try await reader.write(line)
        while true {
            let response = try await nextResponse()
            switch response {
            case .tagged(let receivedTag, let status, let code, let text):
                guard receivedTag == tag else { continue }
                guard status == .ok else { throw MailTransportError.serverRejected(Self.verbatim(status, code, text)) }
                return IMAPCommandResult(untagged: untagged, code: code, text: text, continuations: continuations)
            case .continuation(let text):
                continuations.append(text)
                guard pendingReplies.isEmpty == false else { throw MailTransportError.malformedResponse("continuation") }
                try await reader.write(Data((pendingReplies.removeFirst() + "\r\n").utf8))
            case .status(let status, _, let text):
                if status == .bye { throw MailTransportError.serverRejected("BYE \(text)") }
                untagged.append(response)
            case .data:
                untagged.append(response)
            }
        }
    }

    private func awaitContinuation(tag: String, untagged: inout [IMAPResponse]) async throws {
        while true {
            let response = try await nextResponse()
            switch response {
            case .continuation:
                return
            case .tagged(let receivedTag, let status, let code, let text):
                if receivedTag == tag { throw MailTransportError.serverRejected(Self.verbatim(status, code, text)) }
            case .status(let status, _, let text):
                if status == .bye { throw MailTransportError.serverRejected("BYE \(text)") }
                untagged.append(response)
            case .data:
                untagged.append(response)
            }
        }
    }

    static func quote(_ text: String) -> String? {
        for scalar in text.unicodeScalars where scalar.value == 0 || scalar.value == 10 || scalar.value == 13 || scalar.value > 126 {
            return nil
        }
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }
}
