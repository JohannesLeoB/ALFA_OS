import Foundation
import MykilosServices

enum IMAPFailure {
    static func classify(_ error: any Error) -> Classification {
        if let probe = error as? MailProbeError {
            return classify(probe.reason, provider: probe.step == .incoming ? "imap" : "smtp")
        }
        if let transport = error as? MailTransportError { return classify(transport, provider: nil) }
        return Classification.generic(error)
    }

    private static func classify(_ error: MailTransportError, provider: String?) -> Classification {
        switch error {
        case .connectionFailed(let text):
            return make(.transient, provider ?? "imap", code: "connectionFailed", text: text)
        case .connectionClosed:
            return make(.transient, provider ?? "imap", code: "connectionClosed")
        case .timeout:
            return make(.transient, provider ?? "imap", code: "timeout")
        case .tlsUnavailable:
            return make(.transient, provider ?? "imap", code: "tlsUnavailable")
        case .authenticationRejected(let text):
            return reply(text, provider: provider, fallback: .signIn, authentication: true)
        case .serverRejected(let text):
            return reply(text, provider: provider, fallback: .rejected, authentication: false)
        case .smtpRejected(let code, let text):
            return smtp(code, text, extra: [:], fallback: .rejected)
        case .recipientRejected(let recipient, let code, let text):
            return smtp(code, text, extra: ["recipient": recipient], fallback: .rejected)
        case .credentialsMissing:
            return make(.signIn, provider ?? "imap", code: "credentialsMissing")
        case .oauthUnavailable:
            return make(.signIn, provider ?? "imap", code: "oauthUnavailable")
        case .unsupportedAuthentication(let text):
            return make(.signIn, provider ?? "imap", code: "unsupportedAuthentication", text: text)
        case .accountIncomplete(let text):
            return make(.signIn, provider ?? "imap", code: "accountIncomplete", text: text)
        case .malformedResponse(let text):
            return make(.rejected, provider ?? "imap", code: "malformedResponse", text: text)
        case .invalidRecipient(let text):
            return make(.rejected, provider ?? "smtp", code: "invalidRecipient", text: text)
        case .noRecipients:
            return make(.rejected, provider ?? "smtp", code: "noRecipients")
        case .notImplemented, .folderNotFound, .messageNotFound, .invalidMessageID:
            return make(.rejected, provider ?? "imap", code: String(describing: error))
        }
    }

    private static func make(_ kind: FailureKind, _ provider: String, code: String? = nil, text: String? = nil,
                             status: Int? = nil, extra: [String: String] = [:]) -> Classification {
        Classification(kind: kind, original: Original(provider: provider, status: status, code: code, text: text,
                                                      extra: extra))
    }

    private static func reply(_ text: String, provider: String?, fallback: FailureKind, authentication: Bool)
        -> Classification {
        let first = text.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        if let number = Int(first), (200...599).contains(number) {
            return smtp(number, String(text.dropFirst(first.count)).trimmingCharacters(in: .whitespaces), extra: [:],
                        fallback: fallback, authentication: authentication, whole: text)
        }
        let status = first.uppercased()
        var code: String?
        if let open = text.firstIndex(of: "["), let close = text.firstIndex(of: "]"), open < close {
            code = String(text[text.index(after: open)..<close]).split(separator: " ").first.map(String.init)
        }
        let kind: FailureKind
        switch code?.uppercased() {
        case "UNAVAILABLE": kind = .transient
        case "AUTHENTICATIONFAILED", "AUTHORIZATIONFAILED", "EXPIRED", "PRIVACYREQUIRED": kind = .signIn
        default: kind = status == "BYE" ? .transient : fallback
        }
        return make(kind, provider ?? "imap", code: code?.uppercased(), text: text, extra: ["status": status])
    }

    private static func smtp(_ code: Int, _ text: String, extra: [String: String], fallback: FailureKind,
                             authentication: Bool = false, whole: String? = nil) -> Classification {
        let token = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).first.map(String.init) ?? ""
        let enhanced = isEnhanced(token) ? token : nil
        let kind: FailureKind
        if (400...499).contains(code) {
            kind = .transient
        } else if authentication || code == 530 || code == 535 || enhanced == "5.7.8" {
            kind = .signIn
        } else {
            kind = fallback
        }
        return make(kind, "smtp", code: enhanced ?? String(code), text: whole ?? text, status: code, extra: extra)
    }

    private static func isEnhanced(_ token: String) -> Bool {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let class_ = parts.first, ["2", "4", "5"].contains(String(class_)) else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }
}
