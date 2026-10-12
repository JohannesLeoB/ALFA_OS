import Foundation

public struct AssistantTask: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var done: Bool
    public var dueDate: Date?

    public var projectID: String?

    public var alarmAktiv: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, title: String, done: Bool = false,
                dueDate: Date? = nil, projectID: String? = nil, alarmAktiv: Bool = false,
                createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.done = done
        self.dueDate = dueDate
        self.projectID = projectID
        self.alarmAktiv = alarmAktiv
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, done, dueDate, projectID, alarmAktiv, createdAt, updatedAt
    }
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        done = try container.decode(Bool.self, forKey: .done)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        projectID = try container.decodeIfPresent(String.self, forKey: .projectID)
        alarmAktiv = try container.decodeIfPresent(Bool.self, forKey: .alarmAktiv) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public var ref: String { String(id.prefix(6)) }
}
