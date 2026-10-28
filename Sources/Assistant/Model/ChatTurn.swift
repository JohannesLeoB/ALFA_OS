import Foundation

public struct ChatTurn: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case user
        case assistant
        case streaming
        case failed
    }

    public let id: UUID
    public let kind: Kind
    public let blocks: [TurnBlock]
}
