import Foundation

public struct JournalEntry: Codable, Identifiable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case cannotRead
        case contradiction
        case missingInfo
        case other
    }

    public let id: UUID
    let timestamp: Date
    let projectID: String?
    let kind: Kind
    let text: String

    init(id: UUID = UUID(), timestamp: Date = Date(), projectID: String? = nil, kind: Kind, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.projectID = projectID
        self.kind = kind
        self.text = text
    }
}
