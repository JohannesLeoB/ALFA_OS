import Foundation
import Hub
import enum MykilosServices.MailTransportError

enum MailFailure {
    case transient(Hint)
    case rejected(Hint)

    var hint: Hint {
        switch self {
        case .transient(let hint), .rejected(let hint): hint
        }
    }

    var isTransient: Bool {
        if case .transient = self { return true }
        return false
    }

    static func classify(_ error: Error, inlet: Inlet.ID) -> MailFailure {
        let detail = String(describing: error)
        if error is URLError {
            return .transient(Hint(text: MailHintKey.offline, detail: detail))
        }
        guard let transport = error as? MailTransportError else {
            return .rejected(Hint(text: MailHintKey.failed, detail: detail))
        }
        switch transport {
        case .connectionFailed, .connectionClosed, .timeout, .tlsUnavailable:
            return .transient(Hint(text: MailHintKey.offline, detail: detail))
        case .smtpRejected(let code, _) where (400..<500).contains(code):
            return .transient(Hint(text: MailHintKey.offline, detail: detail))
        case .credentialsMissing, .authenticationRejected, .oauthUnavailable, .unsupportedAuthentication, .accountIncomplete:
            return .rejected(Hint(text: MailHintKey.signIn, detail: detail, fixIn: .inlet(inlet)))
        case .recipientRejected, .invalidRecipient, .noRecipients, .smtpRejected, .serverRejected:
            return .rejected(Hint(text: MailHintKey.rejected, detail: detail))
        default:
            return .rejected(Hint(text: MailHintKey.failed, detail: detail))
        }
    }

    static func hubError(_ error: Error, inlet: Inlet.ID) -> HubError {
        if let hub = error as? HubError { return hub }
        return .provider(classify(error, inlet: inlet).hint)
    }
}
