public struct ListTodosTool: ToolPort {
    private let todos: TodoStore

    public init(todos: TodoStore) {
        self.todos = todos
    }

    public var name: String { "list_tasks" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .tasks }
    public var manifestID: String { "ASSISTANT_TASKS" }
    public var activityKey: String { "assistant.activity.tasks" }
    public var parameters: [ToolParameter] { [ToolParameter("nur_offen"), ToolParameter("alle")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let openOnly = input.flag("nur_offen")
        do {
            let all = input.flag("alle") || scope.projectID == nil
            var found = all ? try await todos.all() : try await todos.scoped(to: scope.projectID)
            if openOnly { found = found.filter { !$0.done } }
            guard found.isEmpty == false else {
                return ToolResult(.make(openOnly ? "assistant.todos.noneOpen" : "assistant.todos.none"))
            }
            return ToolResult(lines: found.map { todo in
                var parts: [Phrase] = [.raw("\(todo.done ? "\u{2713}" : "\u{25CB}") [\(todo.ref)] \(todo.title)")]
                if let project = todo.projectID { parts.append(.make("assistant.common.projectTag", project)) }
                if let date = todo.dueDate { parts.append(.make("assistant.todos.due", ListingEngine.shortDay(date))) }
                return .join(parts, "")
            })
        } catch {
            return .failure("assistant.todos.loadFailed", error.localizedDescription)
        }
    }
}
