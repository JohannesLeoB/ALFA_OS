import Foundation
import AlfaKit

public enum MailProbeStep: String, Sendable {
    case incoming
    case outgoing
}

public struct MailProbeError: Error, Equatable, Sendable {
    public let step: MailProbeStep
    public let reason: MailTransportError

    public init(step: MailProbeStep, reason: MailTransportError) {
        self.step = step
        self.reason = reason
    }
}

public enum MailConnectionProbe {
    public static func probe(account: MailAccount, password: String) async throws {
        try await probe(account: account, password: password, opener: MailStreams.open)
    }

    static func probe(account: MailAccount, password: String, opener: @escaping MailStreamOpener) async throws {
        guard password.isEmpty == false else {
            throw MailProbeError(step: .incoming, reason: .credentialsMissing)
        }
        guard account.incoming.isComplete else {
            throw MailProbeError(step: .incoming, reason: .accountIncomplete("incoming"))
        }
        guard account.outgoing.isComplete else {
            throw MailProbeError(step: .outgoing, reason: .accountIncomplete("outgoing"))
        }
        try await step(.incoming) {
            let user = account.incoming.username.isEmpty ? account.address : account.incoming.username
            let session = try await IMAPSession.open(settings: account.incoming, opener: opener)
            do {
                try await session.authenticate(.password(user: user, secret: password))
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
                try await session.authenticate(.password(user: user, secret: password))
            } catch {
                await session.close()
                throw error
            }
            await session.quit()
        }
    }

    private static func step(_ step: MailProbeStep, _ body: () async throws -> Void) async throws {
        do {
            try await body()
        } catch let error as MailTransportError {
            throw MailProbeError(step: step, reason: error)
        }
    }
}
