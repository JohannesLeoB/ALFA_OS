import Foundation

public struct ListTasksTool: ToolPort {
    static let focusedLimit = 25
    static let overviewLimit = 15
    static let maxLists = 20

    private let board: any TaskBoardPort
    private let lists: [ProjectTaskList]

    public init(board: any TaskBoardPort, lists: [ProjectTaskList]) {
        self.board = board
        self.lists = lists
    }

    public var name: String { "list_clickup_tasks" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .clickUp }
    public var manifestID: String { "CLICKUP_TASKS" }
    public var parameters: [ToolParameter] { [ToolParameter("projekt"), ToolParameter("alle")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        if input.optionalText("projekt") != nil || input.flag("alle") {
            return await overview(filter: input.text("projekt").lowercased())
        }
        return await focused(scope)
    }

    private func focused(_ scope: ToolScope) async -> ToolResult {
        guard let listID = scope.taskListID else { return .failure("assistant.tasks.noList") }
        do {
            let tasks = try await board.openTasks(listID: listID)
            guard tasks.isEmpty == false else { return ToolResult(.make("assistant.tasks.noneInList")) }
            return ToolResult(lines: tasks.prefix(Self.focusedLimit).map { Self.row($0, indent: "", assignee: true) })
        } catch PortFailure.notConnected {
            return .failure("assistant.tasks.notConnected")
        } catch {
            return .failure("assistant.tasks.failed", PortFailure.detail(of: error))
        }
    }

    private func overview(filter: String) async -> ToolResult {
        var refs = lists
        if filter.isEmpty == false {
            refs = refs.filter { $0.projectNumber.lowercased().contains(filter) || $0.title.lowercased().contains(filter) }
        }
        guard refs.isEmpty == false else { return ToolResult(.make("assistant.tasks.noLists")) }
        let limited = Array(refs.prefix(Self.maxLists))
        var blocks: [Phrase] = []
        var total = 0
        var projectCount = 0
        var failed = 0
        for ref in limited {
            do {
                let tasks = try await board.openTasks(listID: ref.listID)
                guard tasks.isEmpty == false else { continue }
                total += tasks.count
                projectCount += 1
                blocks.append(.raw("\(ref.projectNumber) \(ref.title) (\(tasks.count)):"))
                blocks += tasks.prefix(Self.overviewLimit).map { Self.row($0, indent: "  ", assignee: false) }
            } catch PortFailure.notConnected {
                return .failure("assistant.tasks.notConnected")
            } catch {
                failed += 1
            }
        }
        guard blocks.isEmpty == false else { return ToolResult(.make("assistant.tasks.noneOverall")) }
        var lines: [Phrase] = [.make("assistant.tasks.overviewHeader", String(total), String(projectCount))]
        lines += blocks
        if refs.count > limited.count {
            lines.append(.make("assistant.tasks.moreLists", String(refs.count - limited.count), String(Self.maxLists)))
        }
        if failed > 0 { lines.append(.make("assistant.tasks.unreachable", String(failed))) }
        return ToolResult(lines: lines)
    }

    static func row(_ task: TaskItem, indent: String, assignee: Bool) -> Phrase {
        var parts: [Phrase] = [.raw("\(indent)\u{2022} \(task.name) [\(task.status)]")]
        if task.isUrgent { parts.append(.make("assistant.tasks.urgent")) }
        if let due = task.dueDate { parts.append(.make("assistant.tasks.due", ListingEngine.dateTime(due))) }
        if assignee, let who = task.assignee, who.isEmpty == false { parts.append(.raw(" \u{00B7} \(who)")) }
        return .join(parts, "")
    }
}

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

struct ListProjectsTool: ToolPort {
    private let projects: ProjectSearchEngine

    init(projects: ProjectSearchEngine) {
        self.projects = projects
    }

    var name: String { "list_projects" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .studioKnowledge }
    var documented: Bool { false }
    var parameters: [ToolParameter] { [ToolParameter("suche")] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("suche").lowercased()
        let match = projects.filter(query)
        guard match.isEmpty == false else {
            return ToolResult(query.isEmpty ? .make("assistant.projects.none") : .make("assistant.projects.noMatch", query))
        }
        let rows: [Phrase] = match.prefix(ListingEngine.rowLimit).map { entry in
            var parts: [Phrase] = [.raw("\u{2022} \(entry.projectNumber) | \(entry.title)")]
            if let customer = entry.customerName, customer.isEmpty == false { parts.append(.raw(" | \(customer)")) }
            if let phase = entry.phase, phase.isEmpty == false { parts.append(.make("assistant.projects.phase", phase)) }
            if let budget = ListingEngine.money(entry.budget) { parts.append(.make("assistant.projects.budget", budget)) }
            return .join(parts, "")
        }
        return ToolResult(lines: ListingEngine.clip(rows, total: match.count))
    }
}

struct StudioKnowledgeTool: ToolPort {
    static let overviewWords: Set<String> = ["\u{FC}bersicht", "overview", "statistik", "gesamt", "stats"]

    private let knowledge: StudioKnowledge

    init(knowledge: StudioKnowledge) {
        self.knowledge = knowledge
    }

    var name: String { "query_studio_knowledge" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .studioKnowledge }
    var manifestID: String { "STUDIO_KNOWLEDGE_QUERY" }
    var parameters: [ToolParameter] { [ToolParameter("query")] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("query")
        if query.isEmpty || Self.overviewWords.contains(query.lowercased()) {
            return ToolResult(lines: knowledge.overview())
        }
        let hits = knowledge.lookup(query)
        guard hits.isEmpty == false else { return ToolResult(.make("assistant.studio.noHits", query)) }
        return ToolResult(lines: hits.map(knowledge.describe))
    }
}

public struct ListTimeEntriesTool: ToolPort {
    private let time: any TimeEntryPort

    public init(time: any TimeEntryPort) {
        self.time = time
    }

    public var name: String { "list_zeiten" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .time }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("zeitraum")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let period = TimePeriod(rawValue: input.text("zeitraum").lowercased()) ?? .week
        let report = await time.report(period: period)
        if report.entries.isEmpty, let error = report.error { return .failure("assistant.time.error", error) }
        guard report.entries.isEmpty == false else {
            return ToolResult(.make("assistant.time.none", period.rawValue))
        }
        let total = report.entries.reduce(0) { $0 + $1.seconds }
        let rows: [Phrase] = report.entries.prefix(ListingEngine.rowLimit).map { entry in
            var text = "\u{2022} \(ListingEngine.day(entry.start)) | \(entry.customer) | \(entry.service) | \(ListingEngine.duration(entry.seconds))"
            if let note = entry.note, note.isEmpty == false { text += " | \(note)" }
            return .raw(text)
        }
        return ToolResult(lines: [.make("assistant.time.header." + period.rawValue, ListingEngine.hours(total))]
            + ListingEngine.clip(rows, total: report.entries.count))
    }
}
