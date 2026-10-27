import Foundation

public struct ProposeTaskChangeTool: ToolPort {
    private let board: any TaskBoardPort
    private let lists: [ProjectTaskList]

    public init(board: any TaskBoardPort, lists: [ProjectTaskList]) {
        self.board = board
        self.lists = lists
    }

    public var name: String { "propose_clickup_change" }
    public var access: ToolAccess { .propose }
    public var privacy: PrivacyCategory { .clickUp }
    public var manifestID: String { "CLICKUP_TASKS" }
    public var parameters: [ToolParameter] {
        [
            ToolParameter("aktion", required: true),
            ToolParameter("aufgabe", required: true),
            ToolParameter("status"),
            ToolParameter("faellig"),
            ToolParameter("wem"),
            ToolParameter("projekt"),
        ]
    }

    static func day(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = ListingEngine.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let action = input.text("aktion").lowercased()
        let taskName = input.text("aufgabe")
        guard taskName.isEmpty == false else { return .failure("assistant.change.noTaskName") }

        let project = input.text("projekt")
        var listID = scope.taskListID ?? ""
        var projectNumber = scope.projectID ?? ""
        if project.isEmpty == false {
            let match = lists.filter {
                $0.projectNumber.caseInsensitiveCompare(project) == .orderedSame
                    || $0.title.localizedCaseInsensitiveContains(project)
            }
            guard match.count == 1, let ref = match.first else {
                return match.isEmpty
                    ? .failure("assistant.change.noProject", project)
                    : .failure("assistant.change.manyProjects", project, match.map(\.projectNumber).joined(separator: ", "))
            }
            listID = ref.listID
            projectNumber = ref.projectNumber
        }
        guard listID.isEmpty == false else { return .failure("assistant.change.noList") }

        let dueText = input.text("faellig")
        let dueDate = dueText.isEmpty ? nil : Self.day(dueText)
        if dueText.isEmpty == false, dueDate == nil { return .failure("assistant.change.badDate") }

        if action == "anlegen" {
            let draft = ClickUpChangeDraft(intent: .create, listID: listID, projectNumber: projectNumber,
                                           taskName: taskName, dueDate: dueDate)
            return ToolResult(.make("assistant.change.createReady", taskName), cards: [.taskChangeDraft(draft)])
        }

        let tasks: [TaskItem]
        do {
            tasks = try await board.openTasks(listID: listID)
        } catch PortFailure.notConnected {
            return .failure("assistant.tasks.notConnected")
        } catch {
            return .failure("assistant.tasks.failed", PortFailure.detail(of: error))
        }
        let matching = tasks.filter { $0.name.localizedCaseInsensitiveContains(taskName) }
        guard matching.count == 1, let task = matching.first else {
            return matching.isEmpty
                ? .failure("assistant.change.noTask", taskName)
                : .failure("assistant.change.manyTasks", matching.prefix(8).map(\.name).joined(separator: " \u{00B7} "))
        }

        switch action {
        case "status":
            let status = input.text("status")
            guard status.isEmpty == false else { return .failure("assistant.change.noStatus") }
            let draft = ClickUpChangeDraft(intent: .status, listID: listID, projectNumber: projectNumber,
                                           taskID: task.id, taskName: task.name, status: status)
            return ToolResult(.make("assistant.change.statusReady", task.name, status), cards: [.taskChangeDraft(draft)])
        case "faelligkeit":
            guard let dueDate else { return .failure("assistant.change.noDue") }
            let draft = ClickUpChangeDraft(intent: .dueDate, listID: listID, projectNumber: projectNumber,
                                           taskID: task.id, taskName: task.name, dueDate: dueDate)
            return ToolResult(.make("assistant.change.dueReady", task.name, dueText), cards: [.taskChangeDraft(draft)])
        case "zuweisen":
            return await assign(input, listID: listID, projectNumber: projectNumber, task: task)
        default:
            return .failure("assistant.change.unknownAction")
        }
    }

    private func assign(_ input: ToolInput, listID: String, projectNumber: String, task: TaskItem) async -> ToolResult {
        let who = input.text("wem")
        guard who.isEmpty == false else { return .failure("assistant.change.noAssignee") }
        let members: [TaskMember]
        do {
            members = try await board.members(listID: listID)
        } catch {
            return .failure("assistant.change.membersFailed", PortFailure.detail(of: error))
        }
        let matching = members.filter { $0.username.localizedCaseInsensitiveContains(who) }
        guard matching.count == 1, let member = matching.first else {
            return matching.isEmpty
                ? .failure("assistant.change.noMember", who, members.prefix(12).map(\.username).joined(separator: " \u{00B7} "))
                : .failure("assistant.change.manyMembers", who, matching.map(\.username).joined(separator: " \u{00B7} "))
        }
        let draft = ClickUpChangeDraft(intent: .assign, listID: listID, projectNumber: projectNumber,
                                       taskID: task.id, taskName: task.name, memberID: member.id, memberName: member.username)
        return ToolResult(.make("assistant.change.assignReady", task.name, member.username), cards: [.taskChangeDraft(draft)])
    }
}
