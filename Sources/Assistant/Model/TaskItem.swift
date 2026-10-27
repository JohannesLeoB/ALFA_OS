import Foundation

public struct TaskItem: Sendable, Equatable {
    public let id: String
    public let name: String
    public let status: String
    public let isUrgent: Bool
    public let dueDate: Date?
    public let assignee: String?

    public init(id: String, name: String, status: String, isUrgent: Bool = false, dueDate: Date? = nil,
                assignee: String? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.isUrgent = isUrgent
        self.dueDate = dueDate
        self.assignee = assignee
    }
}

public struct TaskMember: Sendable, Equatable {
    public let id: String
    public let username: String

    public init(id: String, username: String) {
        self.id = id
        self.username = username
    }
}

public struct ProjectTaskList: Sendable, Equatable {
    let projectNumber: String
    let title: String
    let listID: String

    init(projectNumber: String, title: String, listID: String) {
        self.projectNumber = projectNumber
        self.title = title
        self.listID = listID
    }
}
