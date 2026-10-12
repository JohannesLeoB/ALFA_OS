import Foundation

public struct AssistantNote: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var body: String

    public var projectID: String?

    public var color: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, body: String, projectID: String? = nil,
                color: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.body = body
        self.projectID = projectID
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var ref: String { String(id.prefix(6)) }
}
