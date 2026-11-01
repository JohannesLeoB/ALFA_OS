import Foundation
import Hub
import Storage

public struct IMAPAccess: ProviderPort {
    static let providerID = "imap"

    public let id: ID = IMAPAccess.providerID
    public let capabilities: Set<Capability> = [.mail]
    public let signIn: any SignInPort
    public let probe: any ProbePort
    private let channels = IMAPChannelRegistry()
    private let database: SQLiteStore?

    public init(database: SQLiteStore? = nil) {
        self.database = database
        signIn = IMAPSignIn(channels: channels)
        probe = ConnectionCheck()
    }

    public var form: [Field] {
        [
            Field(id: ConnectionField.name, title: "field.imap.name"),
            Field(id: ConnectionField.address, title: "field.imap.address"),
            Field(id: ConnectionField.incomingProtocol, title: "field.imap.incomingProtocol"),
            Field(id: ConnectionField.incomingHost, title: "field.imap.incomingHost"),
            Field(id: ConnectionField.incomingPort, title: "field.imap.incomingPort"),
            Field(id: ConnectionField.incomingSecurity, title: "field.imap.incomingSecurity"),
            Field(id: ConnectionField.outgoingHost, title: "field.imap.outgoingHost"),
            Field(id: ConnectionField.outgoingPort, title: "field.imap.outgoingPort"),
            Field(id: ConnectionField.outgoingSecurity, title: "field.imap.outgoingSecurity"),
            Field(id: ConnectionField.username, title: "field.imap.username"),
            Field(id: ConnectionField.password, title: "field.imap.password", secret: true)
        ]
    }

    public var presets: [Preset] {
        ProviderPresets.all.map { entry in
            var values: [Field.ID: String] = [:]
            Self.fill(&values, entry.incoming, host: ConnectionField.incomingHost, port: ConnectionField.incomingPort,
                      security: ConnectionField.incomingSecurity)
            Self.fill(&values, entry.outgoing, host: ConnectionField.outgoingHost, port: ConnectionField.outgoingPort,
                      security: ConnectionField.outgoingSecurity)
            return Preset(id: entry.id, title: entry.title.text, values: values)
        }
    }

    private static func fill(_ values: inout [Field.ID: String], _ template: ServerTemplate, host: String,
                             port: String, security: String) {
        if !template.host.isEmpty { values[host] = template.host }
        if let number = template.port { values[port] = String(number) }
        values[security] = template.security.rawValue
    }

    public func classify(_ error: any Error) -> Classification { MailFailureEngine.classify(error) }

    public func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        let wantsChanges = ObjectIdentifier(port) == ObjectIdentifier((any ChangePort).self)
        guard wantsChanges || ObjectIdentifier(port) == ObjectIdentifier((any MailTransportPort).self) else {
            throw HubFailure.capabilityMissing(inlet.id, inlet.capabilities.first ?? .mail)
        }
        let connection = try ConnectionEngine(values: grant.values)
        let password = connection.password
        if connection.incomingProtocol == .pop3 {
            guard let database else { throw HubFailure.capabilityMissing(inlet.id, .mail) }
            let pop = POPSMTPClient(account: connection.account(id: inlet.id), database: database, password: { password })
            let made: Any = wantsChanges ? POPChangeFeed(transport: pop) : pop
            guard let typed = made as? P else { throw HubFailure.capabilityMissing(inlet.id, .mail) }
            return typed
        }
        let fingerprint = connection.values.sorted { $0.key < $1.key }.map { $0.key + "=" + $0.value }.joined(separator: "\n")
        let transport = IMAPSMTPClient(
            account: connection.account(id: inlet.id), password: { password },
            channel: channels.channel(for: inlet.id, fingerprint: fingerprint))
        let made: Any = wantsChanges ? IMAPChangeFeed(transport: transport) : transport
        guard let typed = made as? P else {
            throw HubFailure.capabilityMissing(inlet.id, .mail)
        }
        return typed
    }
}

struct IMAPSignIn: SignInPort {
    let channels: IMAPChannelRegistry

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        Grant(values: try ConnectionEngine(values: input).values)
    }


    func signOut(_ inlet: Inlet) async throws {
        channels.release(inlet.id)
    }
}

struct ConnectionCheck: ProbePort {
    typealias Run = @Sendable (Account, String) async throws -> Void

    private let run: Run

    init(run: @escaping Run = { try await ConnectionCheck.probe(account: $0, password: $1) }) {
        self.run = run
    }

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        let connection: ConnectionEngine
        do {
            connection = try ConnectionEngine(values: grant.values)
        } catch {
            return ProbeResult(account: inlet.account, rejection: Hint(
                text: "hint.imap.fields.invalid", detail: String(describing: error), fixIn: .inlet(inlet.id)))
        }
        do {
            try await run(connection.account(id: inlet.id), connection.password)
            return ProbeResult(account: connection.address)
        } catch let error as ProbeFailure {
            return ProbeResult(account: connection.address, rejection: Self.hint(error, inlet: inlet.id))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: connection.address, rejection: Hint(
                text: "hint.imap.failed", detail: String(describing: error), fixIn: .inlet(inlet.id),
                kind: error is URLError ? .transient : nil))
        }
    }

    static func hint(_ error: ProbeFailure, inlet: Inlet.ID) -> Hint {
        let protocolName = error.step == .incoming ? "imap" : "smtp"
        let kind: String
        switch error.reason {
        case .authenticationRejected:
            kind = error.step == .incoming ? "login.rejected" : "auth.rejected"
        case .serverRejected, .smtpRejected, .recipientRejected: kind = "refused"
        case .connectionFailed: kind = "connection.failed"
        case .connectionClosed: kind = "connection.closed"
        case .timeout: kind = "connection.timeout"
        case .tlsUnavailable: kind = "tls"
        case .unsupportedAuthentication: kind = "unsupported"
        case .malformedResponse: kind = "malformed"
        case .accountIncomplete, .credentialsMissing: kind = "fields.invalid"
        default: kind = "failed"
        }
        let transient: Bool
        switch error.reason {
        case .connectionFailed, .connectionClosed, .timeout: transient = true
        default: transient = false
        }
        return Hint(text: "hint.\(protocolName).\(kind)", detail: detail(error.reason), fixIn: .inlet(inlet),
                    kind: transient ? .transient : nil)
    }

    static func detail(_ error: MailFailure) -> String? {
        switch error {
        case .authenticationRejected(let text), .serverRejected(let text), .connectionFailed(let text),
             .unsupportedAuthentication(let text), .malformedResponse(let text), .accountIncomplete(let text):
            text
        case .smtpRejected(let code, let text), .recipientRejected(_, let code, let text):
            "\(code) \(text)"
        default:
            nil
        }
    }

    static func probe(account: Account, password: String, opener: @escaping StreamOpener = StreamRouter.open) async throws {
        try await probe(account: account, credential: .password(password), opener: opener)
    }

    static func probe(account: Account, credential: MailCredential,
                      opener: @escaping StreamOpener = StreamRouter.open) async throws {
        guard !credential.isEmpty else {
            throw ProbeFailure(step: .incoming, reason: .credentialsMissing)
        }
        guard account.incoming.isComplete else {
            throw ProbeFailure(step: .incoming, reason: .accountIncomplete("incoming"))
        }
        guard account.outgoing.isComplete else {
            throw ProbeFailure(step: .outgoing, reason: .accountIncomplete("outgoing"))
        }
        try await step(.incoming) {
            let user = account.incoming.username.isEmpty ? account.address : account.incoming.username
            if account.incomingProtocol == .pop3 {
                guard case .password(let secret) = credential else { throw MailFailure.unsupportedAuthentication("pop3") }
                let session = try await POPSession.open(settings: account.incoming, opener: opener)
                do {
                    try await session.authenticate(user: user, secret: secret)
                } catch {
                    await session.close()
                    throw error
                }
                await session.quit()
                return
            }
            let session = try await IMAPClient.open(settings: account.incoming, opener: opener)
            do {
                try await session.authenticate(user: user, credential: credential)
                _ = try await session.run([.raw("NOOP")])
            } catch {
                await session.close()
                throw error
            }
            await session.logout()
        }
        try await step(.outgoing) {
            let user = account.outgoing.username.isEmpty ? account.address : account.outgoing.username
            let session = try await SMTPSession.open(settings: account.outgoing, opener: opener)
            do {
                try await session.authenticate(user: user, credential: credential)
            } catch {
                await session.close()
                throw error
            }
            await session.quit()
        }
    }

    private static func step(_ step: ProbeStep, _ body: () async throws -> Void) async throws {
        do {
            try await body()
        } catch let error as MailFailure {
            throw ProbeFailure(step: step, reason: error)
        }
    }
}

public final class OAuthMailClient: Sendable {
    private let channels = IMAPChannelRegistry()

    public init() {}

    public func transport(for inlet: Inlet.ID, address: String, name: String, endpoints: OAuthMailEndpoints,
                          tokens: any MailTokenPort) -> any MailTransportPort {
        client(for: inlet, address: address, name: name, endpoints: endpoints, tokens: tokens)
    }

    public func changes(for inlet: Inlet.ID, address: String, name: String, endpoints: OAuthMailEndpoints,
                        tokens: any MailTokenPort) -> any ChangePort {
        IMAPChangeFeed(transport: client(for: inlet, address: address, name: name, endpoints: endpoints, tokens: tokens))
    }

    public func probe(inlet: Inlet.ID, address: String, name: String, endpoints: OAuthMailEndpoints,
                      token: String) async throws -> ProbeResult {
        do {
            try await ConnectionCheck.probe(
                account: endpoints.account(id: inlet, address: address, name: name), credential: .accessToken(token))
            return ProbeResult(account: address)
        } catch let error as ProbeFailure {
            return ProbeResult(account: address, rejection: ConnectionCheck.hint(error, inlet: inlet))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: address, rejection: Hint(
                text: "hint.imap.failed", detail: String(describing: error), fixIn: .inlet(inlet),
                kind: error is URLError ? .transient : nil))
        }
    }

    public func release(_ inlet: Inlet.ID) {
        channels.release(inlet)
    }

    public func classify(_ error: any Error) -> Classification {
        MailFailureEngine.classify(error)
    }

    private func client(for inlet: Inlet.ID, address: String, name: String, endpoints: OAuthMailEndpoints,
                        tokens: any MailTokenPort) -> IMAPSMTPClient {
        let fingerprint = [address, endpoints.incomingHost, String(endpoints.incomingPort), endpoints.outgoingHost,
                           String(endpoints.outgoingPort)].joined(separator: "\n")
        return IMAPSMTPClient(
            account: endpoints.account(id: inlet, address: address, name: name),
            credential: { .accessToken(try await tokens.accessToken()) },
            channel: channels.channel(for: inlet, fingerprint: fingerprint),
            filesSentCopy: !endpoints.serverFilesSent)
    }
}

struct IMAPChangeFeed: ChangePort {
    let transport: IMAPSMTPClient

    func changes() -> AsyncThrowingStream<Void, any Error> { transport.changes() }
}

struct POPChangeFeed: ChangePort {
    let transport: POPSMTPClient

    func changes() -> AsyncThrowingStream<Void, any Error> { transport.changes() }
}
