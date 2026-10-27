import Foundation

public struct ClickUpTask: Identifiable, Equatable, Sendable {
    public var id: String
    var name: String
    var status: String
    var dueDate: Date?
    var startDate: Date?
    var assignee: String?
    var assigneeID: String?
    var assigneeIDs: [String]
    var assigneeNames: [String: String]
    var isUrgent: Bool
    var priority: Priority?
    var projectPhase: ProjectPhase?
    var hasCustomFields: Bool
    var isMilestone: Bool
    var tags: [String]
    var statusType: String?
    var dueHasTime: Bool?

    init(id: String, name: String, status: String, dueDate: Date? = nil, startDate: Date? = nil,
         assignee: String? = nil, assigneeID: String? = nil, assigneeIDs: [String] = [],
         assigneeNames: [String: String] = [:], isUrgent: Bool = false, priority: Priority? = nil,
         projectPhase: ProjectPhase? = nil, hasCustomFields: Bool = false, isMilestone: Bool = false,
         statusType: String? = nil, tags: [String] = [], dueHasTime: Bool? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.dueDate = dueDate
        self.startDate = startDate
        self.assignee = assignee
        self.assigneeID = assigneeID
        self.assigneeIDs = assigneeIDs.isEmpty ? Array([assigneeID].compactMap { $0 }) : assigneeIDs
        self.assigneeNames = assigneeNames
        self.isUrgent = isUrgent
        self.priority = priority
        self.projectPhase = projectPhase
        self.hasCustomFields = hasCustomFields
        self.isMilestone = isMilestone
        self.statusType = statusType
        self.tags = tags
        self.dueHasTime = dueHasTime
    }

    func showsDueTime(calendar: Calendar = .current) -> Bool {
        guard let dueDate else { return false }
        if let dueHasTime { return dueHasTime }
        let parts = calendar.dateComponents([.hour, .minute], from: dueDate)
        return (parts.hour == 4 && parts.minute == 0) == false
    }

    var isDone: Bool {
        if let type = statusType?.lowercased(), type.isEmpty == false {
            return type == "done" || type == "closed"
        }
        return status.lowercased() == "complete"
    }
}

public enum Priority: String, CaseIterable, Sendable, Equatable {
    case urgent
    case high
    case normal
    case low

    var nativeValue: Int {
        switch self {
        case .urgent: 1
        case .high: 2
        case .normal: 3
        case .low: 4
        }
    }

    var labelKey: String { "clickup.priority." + rawValue }
}

enum ProjectPhase: Int, CaseIterable, Sendable, Equatable {
    case briefing = 0
    case offer = 1
    case planning = 2
    case order = 3
    case execution = 4
    case completion = 5
    case service = 6

    var labelKey: String {
        switch self {
        case .briefing: "clickup.phase.briefing"
        case .offer: "clickup.phase.offer"
        case .planning: "clickup.phase.planning"
        case .order: "clickup.phase.order"
        case .execution: "clickup.phase.execution"
        case .completion: "clickup.phase.completion"
        case .service: "clickup.phase.service"
        }
    }
}

struct TaskDependencies: Equatable, Sendable {
    struct Reference: Identifiable, Equatable, Sendable {
        var id: String
        var name: String
        var status: String

        init(id: String, name: String, status: String) {
            self.id = id
            self.name = name
            self.status = status
        }
    }

    enum Direction: String, Sendable, Equatable {
        case waitingOn
        case blocking
    }

    var waitingOn: [Reference]
    var blocking: [Reference]

    static let empty = TaskDependencies(waitingOn: [], blocking: [])

    init(waitingOn: [Reference] = [], blocking: [Reference] = []) {
        self.waitingOn = waitingOn
        self.blocking = blocking
    }
}

struct Comment: Identifiable, Equatable, Sendable {
    var id: String
    var text: String
    var authorName: String?
    var authorID: String?
    var postedAt: Date?
    var resolved: Bool

    init(id: String, text: String, authorName: String? = nil, authorID: String? = nil, postedAt: Date? = nil,
         resolved: Bool = false) {
        self.id = id
        self.text = text
        self.authorName = authorName
        self.authorID = authorID
        self.postedAt = postedAt
        self.resolved = resolved
    }
}

public struct Member: Identifiable, Equatable, Sendable {
    public var id: String
    var username: String
    var email: String?

    init(id: String, username: String, email: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
    }
}
