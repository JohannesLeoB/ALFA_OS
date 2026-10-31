import Foundation
import Hub

public enum OutboxState: Equatable, Sendable {
    case waiting
    case checking
    case sending
    case failed(Hint)
    case unverified(Hint)

    public var key: String {
        switch self {
        case .waiting: "mail.outbox.state.waiting"
        case .checking: "mail.outbox.state.checking"
        case .sending: "mail.outbox.state.sending"
        case .failed(let hint): hint.text
        case .unverified: "mail.outbox.state.failed"
        }
    }

    public var offersRowActions: Bool {
        switch self {
        case .waiting, .failed: true
        case .checking, .sending, .unverified: false
        }
    }

    public var inFlight: Bool {
        switch self {
        case .checking, .sending: true
        case .waiting, .failed, .unverified: false
        }
    }

    public var needsAttention: Bool {
        switch self {
        case .failed, .unverified: true
        case .waiting, .checking, .sending: false
        }
    }
}

public struct OutboxItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    let inlet: Inlet.ID
    let draft: Draft
    let messageID: String
    var draftID: String?
    var mirrorID: String?
    private(set) var state: OutboxState
    private(set) var attempts: Int

    init(inlet: Inlet.ID, draft: Draft, draftID: String? = nil) {
        self.init(id: UUID(), inlet: inlet, draft: draft, messageID: UUID().uuidString.lowercased(), draftID: draftID,
                  state: .waiting, attempts: 0)
    }

    init(id: UUID, inlet: Inlet.ID, draft: Draft, messageID: String, draftID: String?, mirrorID: String? = nil,
         state: OutboxState, attempts: Int) {
        self.id = id
        self.inlet = inlet
        self.draft = draft
        self.messageID = messageID
        self.draftID = draftID
        self.mirrorID = mirrorID
        self.state = state
        self.attempts = attempts
    }

    mutating func startSending() {
        state = .sending
        attempts += 1
    }

    mutating func startChecking() {
        state = .checking
        attempts += 1
    }

    mutating func proceed() {
        guard state == .checking else { return }
        state = .sending
    }

    mutating func wait() { state = .waiting }

    mutating func fail(_ hint: Hint) { state = .failed(hint) }

    mutating func unverify(_ hint: Hint) { state = .unverified(hint) }
}

public enum SendOutcome: Equatable, Sendable {
    case sent
    case queued(OutboxItem.ID)
}
