import Foundation

public struct AssistantTagebuchEintrag: Codable, Identifiable, Sendable, Equatable {
    public enum Art: String, Codable, Sendable, CaseIterable {
        case kannNichtLesen

        case widerspruch

        case fehlendeInfo

        case sonstiges
    }

    public let id: UUID
    public let timestamp: Date

    public let projectID: String?
    public let art: Art
    public let text: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        projectID: String? = nil,
        art: Art,
        text: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.projectID = projectID
        self.art = art
        self.text = text
    }
}
