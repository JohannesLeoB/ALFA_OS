import Foundation
import Hub

public enum OutboxState: Equatable, Sendable {
    case waiting
    case sending
    case failed(Hint)
}

public struct OutboxItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    let inlet: Inlet.ID
    let draft: Draft
    let messageID: String
    var draftID: String?
    private(set) var state: OutboxState
    private(set) var attempts: Int

    init(inlet: Inlet.ID, draft: Draft, draftID: String? = nil) {
        self.init(id: UUID(), inlet: inlet, draft: draft, messageID: UUID().uuidString.lowercased(), draftID: draftID,
                  state: .waiting, attempts: 0)
    }

    init(id: UUID, inlet: Inlet.ID, draft: Draft, messageID: String, draftID: String?, state: OutboxState, attempts: Int) {
        self.id = id
        self.inlet = inlet
        self.draft = draft
        self.messageID = messageID
        self.draftID = draftID
        self.state = state
        self.attempts = attempts
    }

    mutating func startSending() {
        state = .sending
        attempts += 1
    }

    mutating func wait() { state = .waiting }

    mutating func fail(_ hint: Hint) { state = .failed(hint) }
}

public enum SendOutcome: Equatable, Sendable {
    case sent
    case queued(OutboxItem.ID)
}
