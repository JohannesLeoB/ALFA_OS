public struct CompleteTodoTool: ToolPort {
    private let todos: TodoStore
    private let alarm: any AlarmPort

    public init(todos: TodoStore, alarm: any AlarmPort) {
        self.todos = todos
        self.alarm = alarm
    }

    public var name: String { "complete_task" }
    public var access: ToolAccess { .write }
    public var privacy: PrivacyCategory { .tasks }
    public var manifestID: String { "ASSISTANT_TASKS" }
    public var activityKey: String { "assistant.activity.tasks" }
    public var parameters: [ToolParameter] { [ToolParameter("aufgabe", required: true), ToolParameter("erledigt")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("aufgabe")
        guard query.isEmpty == false else { return .failure("assistant.todos.whichTodo") }
        let done = input.text("erledigt").lowercased() != "false"
        do {
            guard let todo = try await todos.setDone(matching: query, done: done, scopedTo: scope.projectID) else {
                return .failure("assistant.todos.notFound", query)
            }
            await alarm.reschedule(todo)
            return ToolResult(.make(done ? "assistant.todos.completed" : "assistant.todos.reopened", todo.ref, todo.title))
        } catch {
            return .failure("assistant.todos.updateFailed", error.localizedDescription)
        }
    }
}
