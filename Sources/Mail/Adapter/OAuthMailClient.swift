import Foundation
import Hub

public final class OAuthMailClient: Sendable {
    private let channels = IMAPChannelRegistry()

    public init() {}

    public func transport(for inlet: Inlet.ID, address: String, name: String, endpoints: OAuthMailEndpoints,
                          tokens: any MailTokenPort) -> any MailTransportPort {
        client(for: inlet, address: address, name: name, endpoints: endpoints, tokens: tokens)
    }

    public func changes(for inlet: Inlet.ID, address: String, name: String, endpoints: OAuthMailEndpoints,
                        tokens: any MailTokenPort) -> any ChangePort {
        IMAPChangePort(transport: client(for: inlet, address: address, name: name, endpoints: endpoints, tokens: tokens))
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
        FailureEngine.classify(error)
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
