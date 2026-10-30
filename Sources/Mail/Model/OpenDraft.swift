import Foundation
import Hub

public struct OpenDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var inlet: Inlet.ID
    public var draft: Draft
    public var state: DraftState
    public var outboxID: OutboxItem.ID?
    public var remoteID: String?
    public var mirrorID: String?
    public var saveFailure: Hint?
    public var tooLarge = false

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
        return Self.asksSignIn(hint)
    }

    public var saveNeedsSignIn: Bool {
        saveFailure.map(Self.asksSignIn) ?? false
    }

    private static func asksSignIn(_ hint: Hint) -> Bool {
        hint.kind == .signIn || hint.text == Hint.signInExpiredText
    }

    public var failedToSend: Bool {
        if case .sendFailed = state { return !needsGrant }
        return false
    }

    public var status: DraftStatus? {
        switch state {
        case .sending: return .sending
        case .queuedInOutbox: return .outbox
        case .saving: return .saving
        case .saved: return .saved
        default: break
        }
        if tooLarge { return .tooLarge }
        if failedToSend { return .sendFailed }
        return saveFailure == nil ? nil : .notSaved
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
    case saving
    case saved
    case sending
    case outbox
    case sendFailed
    case notSaved
    case tooLarge

    public var key: String {
        switch self {
        case .saving: "mail.draft.saving"
        case .saved: "mail.draft.saved"
        case .sending: "mail.draft.sending"
        case .outbox: "mail.draft.outbox"
        case .sendFailed: "mail.draft.sendFailed"
        case .notSaved: "mail.draft.notSaved"
        case .tooLarge: "mail.draft.tooLarge"
        }
    }

    public var failed: Bool { self == .sendFailed || self == .notSaved || self == .tooLarge }
}
