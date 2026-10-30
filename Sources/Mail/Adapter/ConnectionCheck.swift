import Foundation
import Hub

enum ProbeStep: String, Sendable {
    case incoming
    case outgoing
}

struct ProbeFailure: Error, Equatable, Sendable {
    let step: ProbeStep
    let reason: MailFailure
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
