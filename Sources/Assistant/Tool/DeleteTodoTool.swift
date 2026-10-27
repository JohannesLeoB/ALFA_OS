public struct DeleteTodoTool: ToolPort {
    private let todos: TodoStore
    private let alarm: any AlarmPort

    public init(todos: TodoStore, alarm: any AlarmPort) {
        self.todos = todos
        self.alarm = alarm
    }

    public var name: String { "delete_task" }
    public var access: ToolAccess { .write }
    public var privacy: PrivacyCategory { .tasks }
    public var manifestID: String { "ASSISTANT_TASKS" }
    public var activityKey: String { "assistant.activity.tasks" }
    public var parameters: [ToolParameter] { [ToolParameter("aufgabe", required: true)] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("aufgabe")
        guard query.isEmpty == false else { return .failure("assistant.todos.whichTodo") }
        do {
            guard let todo = try await todos.delete(matching: query, scopedTo: scope.projectID) else {
                return .failure("assistant.todos.notFound", query)
            }
            await alarm.cancel(todoID: todo.id)
            return ToolResult(.make("assistant.todos.deleted", todo.ref, todo.title))
        } catch {
            return .failure("assistant.todos.deleteFailed", error.localizedDescription)
        }
    }
}
