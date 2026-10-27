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
