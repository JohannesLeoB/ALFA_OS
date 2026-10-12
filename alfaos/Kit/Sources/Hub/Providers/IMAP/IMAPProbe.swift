import Foundation
import MykilosKit
import MykilosServices

package typealias IMAPProbeRun = @Sendable (MailAccount, String) async throws -> Void

struct IMAPProbe: ProbePort {
    let run: IMAPProbeRun

    init(run: @escaping IMAPProbeRun = { try await MailConnectionProbe.probe(account: $0, password: $1) }) {
        self.run = run
    }

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        let connection: IMAPConnection
        do {
            connection = try IMAPConnection(values: grant.values)
        } catch {
            return ProbeResult(account: inlet.account, rejection: Hint(
                text: "hint.imap.fields.invalid", detail: String(describing: error), fixIn: .inlet(inlet.id)))
        }
        do {
            try await run(connection.account(id: inlet.id), connection.password)
            return ProbeResult(account: connection.address)
        } catch let error as MailProbeError {
            return ProbeResult(account: connection.address, rejection: Self.hint(error, inlet: inlet.id))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return ProbeResult(account: connection.address, rejection: Hint(
                text: "hint.imap.failed", detail: String(describing: error), fixIn: .inlet(inlet.id)))
        }
    }

    static func hint(_ error: MailProbeError, inlet: Inlet.ID) -> Hint {
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
        return Hint(text: "hint.\(protocolName).\(kind)", detail: detail(error.reason), fixIn: .inlet(inlet))
    }

    static func detail(_ error: MailTransportError) -> String? {
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
}
