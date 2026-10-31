import Foundation
import Hub

@MainActor
enum DeliveryEngine {
    nonisolated private static let sizeReplies: Set<Int> = [552, 413]
    nonisolated private static let sizeCodes: Set<String> = ["5.3.4", "5.2.3"]

    enum Failure {
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
    }

    enum Delivery {
        case sent
        case transient(Hint)
        case rejected(Hint)
        case unverified(Hint)
    }

    static func classify(_ error: Error, inlet: Inlet.ID, access: any AccessPort) -> Failure {
        let classification = access.classify(error, inlet: inlet)
        switch classification.kind {
        case .transient:
            return .transient(Hint(text: MessageTextKey.offline.rawValue, classification: classification))
        case .signIn:
            return .rejected(Hint(text: Hint.signInExpiredText, classification: classification, fixIn: .inlet(inlet)))
        case .rejected:
            if tooLarge(classification.original) {
                return .rejected(Hint(text: MessageTextKey.tooLarge.rawValue, classification: classification))
            }
            let text = classification.original.provider == "unknown" ? MessageTextKey.failed.rawValue : MessageTextKey.rejected.rawValue
            return .rejected(Hint(text: text, classification: classification))
        }
    }

    nonisolated static func tooLarge(_ original: Original) -> Bool {
        original.status.map(sizeReplies.contains) == true || original.code.map(sizeCodes.contains) == true
    }

    static func hubFailure(_ error: Error, inlet: Inlet.ID, access: any AccessPort) -> HubFailure {
        if let failure = error as? HubFailure { return failure }
        return .provider(classify(error, inlet: inlet, access: access).hint)
    }

    static func deliver(_ item: inout OutboxItem, verify: Bool, byUser: Bool, access: any AccessPort, folder: (FolderRole) -> String?,
                        checked: () -> Void = {}, stored: (SavedDraft, Draft, String?) -> Void = { _, _, _ in }) async -> Delivery {
        let transport: any MailTransportPort
        do {
            transport = try access.port((any MailTransportPort).self, for: item.inlet)
        } catch {
            return .transient(Hint(text: MessageTextKey.offline.rawValue, detail: String(describing: error)))
        }
        if verify {
            do {
                if try await transport.wasSent(messageID: item.messageID, in: folder(.sent)) { return .sent }
            } catch {
                let failure = classify(error, inlet: item.inlet, access: access)
                if failure.isTransient { return .transient(failure.hint) }
                if !byUser { return .unverified(failure.hint) }
            }
            checked()
        }
        var outgoing = item.draft
        outgoing.messageID = item.messageID
        do {
            if let draftID = item.draftID {
                let saved = try await transport.saveDraft(outgoing, replacing: draftID, into: folder(.drafts))
                stored(saved, outgoing, item.mirrorID)
                item.draftID = saved.id
                item.mirrorID = saved.mirrorID
                try await transport.sendDraft(id: saved.id)
            } else {
                try await transport.send(outgoing)
            }
            if let copier = transport as? any SentCopyPort, copier.filesSentCopy {
                try? await copier.fileSent(outgoing, into: folder(.sent))
            }
            return .sent
        } catch {
            switch classify(error, inlet: item.inlet, access: access) {
            case .transient(let hint): return .transient(hint)
            case .rejected(let hint): return .rejected(hint)
            }
        }
    }
}

enum FailureEngine {
    private static let successMin = 200
    private static let rejectMax = 599
    private static let transientMin = 400
    private static let transientMax = 499
    private static let authCode = 530
    private static let loginCode = 535

    static func classify(_ error: any Error) -> Classification {
        if let probe = error as? ProbeFailure {
            return classify(probe.reason, provider: probe.step == .incoming ? "imap" : "smtp")
        }
        if let failure = error as? MailFailure { return classify(failure, provider: nil) }
        return Classification.generic(error)
    }

    private static func classify(_ error: MailFailure, provider: String?) -> Classification {
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
        case .unsupportedAuthentication(let text):
            return make(.signIn, provider ?? "imap", code: "unsupportedAuthentication", text: text)
        case .unsupportedCapability(let text):
            return make(.rejected, provider ?? "imap", code: "unsupportedCapability", text: text)
        case .accountIncomplete(let text):
            return make(.signIn, provider ?? "imap", code: "accountIncomplete", text: text)
        case .malformedResponse(let text):
            return make(.rejected, provider ?? "imap", code: "malformedResponse", text: text)
        case .invalidRecipient(let text):
            return make(.rejected, provider ?? "smtp", code: "invalidRecipient", text: text)
        case .noRecipients:
            return make(.rejected, provider ?? "smtp", code: "noRecipients")
        case .folderNotFound, .messageNotFound, .invalidMessageID:
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
        if let number = Int(first), (successMin...rejectMax).contains(number) {
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
        if (transientMin...transientMax).contains(code) {
            kind = .transient
        } else if authentication || code == authCode || code == loginCode || enhanced == "5.7.8" {
            kind = .signIn
        } else {
            kind = fallback
        }
        return make(kind, "smtp", code: enhanced ?? String(code), text: whole ?? text, status: code, extra: extra)
    }

    private static func isEnhanced(_ token: String) -> Bool {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let first = parts.first, ["2", "4", "5"].contains(String(first)) else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    }
}

enum AutosaveEngine {
    static let pause: Duration = .seconds(3)
    static let interval: Duration = .seconds(30)
    static let quitLimit: Duration = .seconds(4)
}
