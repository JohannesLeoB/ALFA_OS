import Foundation
import Hub

public struct OpenDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var inlet: Inlet.ID
    public var draft: Draft
    public var state: DraftState
    public var outboxID: OutboxItem.ID?
    public var remoteID: String?
    public var saveFailure: Hint?

    public func people(_ field: RecipientField) -> [Participant] {
        switch field {
        case .to: RecipientEngine.parse(draft.to)
        case .cc: RecipientEngine.parse(draft.cc)
        case .bcc: RecipientEngine.parse(draft.bcc)
        }
    }

    public var canSend: Bool {
        switch state {
        case .sending, .queuedInOutbox, .sent: return false
        default: break
        }
        return !people(.to).isEmpty && !draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var needsGrant: Bool {
        guard case .sendFailed(let hint) = state else { return false }
        return hint.kind == .signIn || hint.text == Hint.signInExpiredText
    }

    public var failedToSend: Bool {
        if case .sendFailed = state { return !needsGrant }
        return false
    }

    public var status: DraftStatus? {
        switch state {
        case .sending, .queuedInOutbox: return .sending
        case .saved: return .saved
        default: break
        }
        if people(.to).isEmpty { return .recipientMissing }
        if draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .subjectMissing }
        return failedToSend ? .sendFailed : nil
    }
}

public enum DraftState: Equatable, Sendable {
    case idle
    case edited
    case saving
    case saved(Date)
    case sending
    case sent
    case sendFailed(Hint)
    case queuedInOutbox
}

public enum DraftStatus: Equatable, Sendable {
    case sending
    case saved
    case recipientMissing
    case subjectMissing
    case sendFailed

    public var key: String {
        switch self {
        case .sending: "mail.draft.sending"
        case .saved: "mail.draft.saved"
        case .recipientMissing: "mail.toast.recipientMissing"
        case .subjectMissing: "mail.draft.subjectMissing"
        case .sendFailed: "mail.draft.sendFailed"
        }
    }

    public var failed: Bool { self == .sendFailed }
}
