import Foundation

public struct ClickUpChangeDraft: Codable, Sendable, Equatable {
    public enum Intent: String, Codable, Sendable { case create, status, dueDate, assign }

    public var intent: Intent
    public var listID: String
    public var projectNumber: String
    public var taskID: String?
    public var taskName: String
    public var status: String?
    public var dueDate: Date?
    public var memberID: String?
    var memberName: String?

    public init(intent: Intent, listID: String, projectNumber: String, taskID: String? = nil, taskName: String,
                status: String? = nil, dueDate: Date? = nil, memberID: String? = nil, memberName: String? = nil) {
        self.intent = intent
        self.listID = listID
        self.projectNumber = projectNumber
        self.taskID = taskID
        self.taskName = taskName
        self.status = status
        self.dueDate = dueDate
        self.memberID = memberID
        self.memberName = memberName
    }
}
