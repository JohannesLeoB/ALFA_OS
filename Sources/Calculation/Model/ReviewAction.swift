import Foundation

struct ReviewAction: Equatable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    let candidateID: String
    let kind: ReviewActionKind
    let note: String

    init(id: UUID = UUID(), createdAt: Date = Date(), candidateID: String, kind: ReviewActionKind, note: String) {
        self.id = id
        self.createdAt = createdAt
        self.candidateID = candidateID
        self.kind = kind
        self.note = note
    }
}

enum ReviewActionKind: String, Sendable {
    case releaseAsActiveAnchor
    case addUserNote
}
