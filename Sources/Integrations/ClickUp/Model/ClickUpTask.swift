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

struct FieldOption: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var orderIndex: Int?

    init(id: String, name: String, orderIndex: Int? = nil) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
    }
}

struct CustomField: Identifiable, Equatable, Sendable {
    enum WriteKind: Equatable, Sendable {
        case text
        case checkbox
        case date
        case dropdown
        case labels
        case none
    }

    var id: String
    var name: String
    var type: String
    var rawValue: String
    var options: [FieldOption]

    init(id: String, name: String, type: String, rawValue: String, options: [FieldOption] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.rawValue = rawValue
        self.options = options
    }

    var writeKind: WriteKind {
        switch type {
        case "text", "short_text", "number", "url", "email", "phone": .text
        case "checkbox": .checkbox
        case "date": .date
        case "drop_down": options.isEmpty ? .none : .dropdown
        case "labels": options.isEmpty ? .none : .labels
        default: .none
        }
    }

    func optionID(forLabel label: String) throws -> String? {
        let matches = options.filter { $0.name.caseInsensitiveCompare(label) == .orderedSame }
        guard matches.count <= 1 else {
            throw ClickUpFailure.ambiguousOption(field: name, label: label, count: matches.count)
        }
        return matches.first?.id
    }

    static func unique(named name: String, in fields: [CustomField]) throws -> CustomField? {
        let matches = fields.filter { $0.name == name }
        guard matches.count <= 1 else { throw ClickUpFailure.ambiguousField(name: name, count: matches.count) }
        return matches.first
    }
}

enum ProjectTemplate {
    static let taskKeys: [String] = [
        "clickup.template.qualifyLead",
        "clickup.template.checkBriefing",
        "clickup.template.prepareMeasurement",
        "clickup.template.startPlanning",
        "clickup.template.prepareOffer",
        "clickup.template.checkOrder",
        "clickup.template.agreeInstallation",
        "clickup.template.closeAndReview",
    ]

    static var anchorKey: String { taskKeys[0] }

    static func anchor(in tasks: [ClickUpTask], named name: String) throws -> ClickUpTask? {
        let named = tasks.filter { $0.name == name }
        guard named.count <= 1 else { throw ClickUpFailure.ambiguousAnchor(name: name, count: named.count) }
        if let match = named.first { return match }
        return tasks.first(where: \.hasCustomFields)
    }

    static func phase(in tasks: [ClickUpTask], anchorName: String) -> ProjectPhase? {
        (try? anchor(in: tasks, named: anchorName))?.projectPhase
    }
}

enum ClickUpFailure: Error, Equatable, Sendable {
    case notConnected
    case invalidResponse
    case http(Int)
    case decoding
    case ambiguousAnchor(name: String, count: Int)
    case ambiguousField(name: String, count: Int)
    case ambiguousOption(field: String, label: String, count: Int)

    var detail: String {
        switch self {
        case .notConnected: "notConnected"
        case .invalidResponse: "invalidResponse"
        case .http(let code): "http \(code)"
        case .decoding: "decoding"
        case .ambiguousAnchor(let name, let count): "ambiguousAnchor \(name) \(count)"
        case .ambiguousField(let name, let count): "ambiguousField \(name) \(count)"
        case .ambiguousOption(let field, let label, let count): "ambiguousOption \(field) \(label) \(count)"
        }
    }
}
