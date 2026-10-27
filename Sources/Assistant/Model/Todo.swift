import Foundation

public struct Todo: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    var title: String
    var done: Bool
    var dueDate: Date?
    var projectID: String?
    var alarmActive: Bool
    let createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, title: String, done: Bool = false, dueDate: Date? = nil,
         projectID: String? = nil, alarmActive: Bool = false, createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.done = done
        self.dueDate = dueDate
        self.projectID = projectID
        self.alarmActive = alarmActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var ref: String { String(id.prefix(6)) }
}
