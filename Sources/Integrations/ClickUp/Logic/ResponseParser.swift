import Foundation

enum ResponseParser {
    static let phaseFieldName = "project_phase"

    static func tasks(from data: Data) throws -> [ClickUpTask] {
        try decode(TasksResponse.self, from: data).tasks.map(task(from:))
    }

    static func subtasks(from data: Data) throws -> [ClickUpTask] {
        try decode(TaskDetail.self, from: data).subtasks.map { $0.map(task(from:)) } ?? []
    }

    static func content(from data: Data) throws -> String? {
        try decode(TaskDetail.self, from: data).textContent
    }

    static func customFields(from data: Data) throws -> [CustomField] {
        (try decode(TaskDetail.self, from: data).customFields ?? []).map { field in
            CustomField(id: field.id ?? "", name: field.name ?? "", type: field.type ?? "",
                        rawValue: field.value?.displayString ?? "", options: field.typeConfig?.mappedOptions ?? [])
        }
    }

    static func dependencyIDs(from data: Data, ownTaskID: String) throws -> (waitingOn: [String], blocking: [String]) {
        var waitingOn: [String] = []
        var blocking: [String] = []
        for dependency in try decode(TaskDetail.self, from: data).dependencies ?? [] {
            guard let taskID = dependency.taskID, let dependsOn = dependency.dependsOn else { continue }
            if taskID == ownTaskID { waitingOn.append(dependsOn) } else if dependsOn == ownTaskID { blocking.append(taskID) }
        }
        return (waitingOn, blocking)
    }

    static func reference(id: String, from data: Data) -> TaskDependencies.Reference {
        guard let detail = try? decode(TaskDetail.self, from: data) else {
            return TaskDependencies.Reference(id: id, name: id, status: "")
        }
        return TaskDependencies.Reference(id: id, name: detail.name, status: detail.status?.status ?? "")
    }

    static func comments(from data: Data) throws -> [Comment] {
        try decode(CommentsResponse.self, from: data).comments.map { entity in
            Comment(id: entity.id ?? "", text: entity.commentText ?? "", authorName: entity.user?.username,
                    authorID: entity.user?.id.map(String.init), postedAt: date(fromEpochMillis: entity.date),
                    resolved: entity.resolved ?? false)
        }
    }

    static func members(from data: Data) throws -> [Member] {
        try decode(MembersResponse.self, from: data).members.map { Member(id: String($0.id), username: $0.username ?? "") }
    }

    static func fieldCatalog(from data: Data) throws -> [CustomField] {
        try decode(FieldCatalogResponse.self, from: data).fields.map { field in
            CustomField(id: field.id ?? "", name: field.name ?? "", type: field.type ?? "", rawValue: "",
                        options: field.typeConfig?.mappedOptions ?? [])
        }
    }

    static func user(from data: Data) throws -> Member {
        let user = try decode(UserResponse.self, from: data).user
        return Member(id: String(user.id), username: user.username, email: user.email)
    }

    static func createdID(from data: Data) throws -> String {
        try decode(Created.self, from: data).id
    }

    static func listID(named name: String, from data: Data) throws -> String? {
        try decode(ListsResponse.self, from: data).lists.first { $0.name == name }?.id
    }

    static func firstTeamID(from data: Data) throws -> String {
        guard let id = try decode(TeamsResponse.self, from: data).teams.first?.id else { throw ClickUpFailure.decoding }
        return id
    }

    static func date(fromEpochMillis millis: String?) -> Date? {
        guard let millis, let value = Double(millis) else { return nil }
        return Date(timeIntervalSince1970: value / 1000.0)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ClickUpFailure.decoding
        }
    }

    private static func task(from entity: TaskEntity) -> ClickUpTask {
        let phaseIndex = entity.customFields?.first(where: { $0.name == phaseFieldName })?.value
        let assignees = entity.assignees ?? []
        return ClickUpTask(
            id: entity.id,
            name: entity.name,
            status: entity.status?.status ?? "",
            dueDate: date(fromEpochMillis: entity.dueDate),
            startDate: date(fromEpochMillis: entity.startDate),
            assignee: assignees.first?.username,
            assigneeID: assignees.first?.id.map(String.init),
            assigneeIDs: assignees.compactMap { $0.id.map(String.init) },
            assigneeNames: Dictionary(
                assignees.compactMap { assignee in assignee.id.map { (String($0), assignee.username ?? "") } },
                uniquingKeysWith: { first, _ in first }),
            isUrgent: entity.priority?.priority?.lowercased() == "urgent",
            priority: Priority(rawValue: entity.priority?.priority?.lowercased() ?? ""),
            projectPhase: phaseIndex.flatMap(ProjectPhase.init(rawValue:)),
            hasCustomFields: entity.customFields?.isEmpty == false,
            isMilestone: entity.customItemID == 1,
            statusType: entity.status?.type,
            tags: (entity.tags ?? []).compactMap { $0.name },
            dueHasTime: entity.dueDateTime)
    }

    private struct ListsResponse: Decodable {
        struct Entry: Decodable {
            var id: String
            var name: String
        }

        var lists: [Entry]
    }

    private struct Created: Decodable {
        var id: String
    }

    private struct MembersResponse: Decodable {
        struct Entry: Decodable {
            var id: Int
            var username: String?
        }

        var members: [Entry]
    }

    private struct FieldCatalogResponse: Decodable {
        struct Entry: Decodable {
            var id: String?
            var name: String?
            var type: String?
            var typeConfig: TypeConfig?

            enum CodingKeys: String, CodingKey {
                case id, name, type
                case typeConfig = "type_config"
            }
        }

        var fields: [Entry]
    }

    private struct UserResponse: Decodable {
        struct Entry: Decodable {
            var id: Int
            var username: String
            var email: String?
        }

        var user: Entry
    }

    private struct TeamsResponse: Decodable {
        struct Entry: Decodable {
            var id: String
        }

        var teams: [Entry]
    }

    private struct TasksResponse: Decodable {
        var tasks: [TaskEntity]
    }

    private struct TaskEntity: Decodable {
        struct Status: Decodable {
            var status: String?
            var type: String?
        }

        struct PriorityEntry: Decodable {
            var priority: String?
        }

        struct Assignee: Decodable {
            var id: Int?
            var username: String?
        }

        struct Tag: Decodable {
            var name: String?
        }

        struct CustomFieldEntry: Decodable {
            var name: String
            var value: Int?

            private enum CodingKeys: String, CodingKey { case name, value }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                name = try container.decode(String.self, forKey: .name)
                value = try? container.decode(Int.self, forKey: .value)
            }
        }

        var id: String
        var name: String
        var status: Status?
        var dueDate: String?
        var dueDateTime: Bool?
        var startDate: String?
        var priority: PriorityEntry?
        var assignees: [Assignee]?
        var customFields: [CustomFieldEntry]?
        var customItemID: Int?
        var tags: [Tag]?

        enum CodingKeys: String, CodingKey {
            case id, name, status, priority, assignees, tags
            case dueDate = "due_date"
            case dueDateTime = "due_date_time"
            case startDate = "start_date"
            case customFields = "custom_fields"
            case customItemID = "custom_item_id"
        }
    }

    private struct TaskDetail: Decodable {
        struct Status: Decodable {
            var status: String?
        }

        struct Dependency: Decodable {
            var taskID: String?
            var dependsOn: String?

            enum CodingKeys: String, CodingKey {
                case taskID = "task_id"
                case dependsOn = "depends_on"
            }
        }

        struct Field: Decodable {
            var id: String?
            var name: String?
            var type: String?
            var value: AnyValue?
            var typeConfig: TypeConfig?

            enum CodingKeys: String, CodingKey {
                case id, name, type, value
                case typeConfig = "type_config"
            }
        }

        var name: String
        var status: Status?
        var dependencies: [Dependency]?
        var customFields: [Field]?
        var subtasks: [TaskEntity]?
        var textContent: String?

        enum CodingKeys: String, CodingKey {
            case name, status, dependencies, subtasks
            case customFields = "custom_fields"
            case textContent = "text_content"
        }
    }

    private struct TypeConfig: Decodable {
        struct Option: Decodable {
            var id: String?
            var name: String?
            var label: String?
            var orderIndex: Int?

            enum CodingKeys: String, CodingKey {
                case id, name, label
                case orderIndex = "orderindex"
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try? container.decode(String.self, forKey: .id)
                name = try? container.decode(String.self, forKey: .name)
                label = try? container.decode(String.self, forKey: .label)
                orderIndex = try? container.decode(Int.self, forKey: .orderIndex)
            }
        }

        var options: [Option]?

        var mappedOptions: [FieldOption] {
            (options ?? []).compactMap { option in
                guard let id = option.id else { return nil }
                return FieldOption(id: id, name: option.name ?? option.label ?? "", orderIndex: option.orderIndex)
            }
        }
    }

    private struct AnyValue: Decodable {
        let displayString: String

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) { displayString = text; return }
            if let number = try? container.decode(Double.self) {
                displayString = number.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(number)) : String(number)
                return
            }
            if let flag = try? container.decode(Bool.self) { displayString = flag ? "true" : "false"; return }
            if let list = try? container.decode([String].self) { displayString = list.joined(separator: ", "); return }
            displayString = ""
        }
    }

    private struct CommentsResponse: Decodable {
        struct Entry: Decodable {
            struct User: Decodable {
                var id: Int?
                var username: String?
            }

            var id: String?
            var commentText: String?
            var user: User?
            var date: String?
            var resolved: Bool?

            enum CodingKeys: String, CodingKey {
                case id, user, date, resolved
                case commentText = "comment_text"
            }
        }

        var comments: [Entry]
    }
}
