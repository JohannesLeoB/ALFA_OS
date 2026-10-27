import Foundation

public struct CreateTodoTool: ToolPort {
    private let todos: TodoStore
    private let alarm: any AlarmPort

    public init(todos: TodoStore, alarm: any AlarmPort) {
        self.todos = todos
        self.alarm = alarm
    }

    public var name: String { "create_task" }
    public var access: ToolAccess { .write }
    public var privacy: PrivacyCategory { .tasks }
    public var manifestID: String { "ASSISTANT_TASKS" }
    public var activityKey: String { "assistant.activity.tasks" }
    public var parameters: [ToolParameter] { [ToolParameter("titel", required: true), ToolParameter("faellig")] }

    static func parseDue(_ raw: String?) -> Date? {
        let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return nil }
        if let date = ISO8601DateFormatter().date(from: text) { return date }
        for pattern in ["yyyy-MM-dd", "dd.MM.yyyy", "dd.MM.yy"] {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "de_DE")
            formatter.timeZone = ListingEngine.timeZone
            formatter.dateFormat = pattern
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let title = input.optionalText("titel") ?? input.text("text")
        guard title.isEmpty == false else { return .failure("assistant.todos.noTitle") }
        let due = Self.parseDue(input.text("faellig"))
        do {
            let todo = try await todos.create(title, dueDate: due, projectID: scope.projectID, alarmActive: due != nil)
            await alarm.reschedule(todo)
            var parts: [Phrase] = [.make("assistant.todos.created", todo.ref)]
            if let project = todo.projectID { parts.append(.make("assistant.common.inProject", project)) }
            parts.append(.raw(": \(todo.title)"))
            if let date = todo.dueDate { parts.append(.make("assistant.todos.due", ListingEngine.shortDay(date))) }
            return ToolResult(.join(parts, ""))
        } catch {
            return .failure("assistant.todos.saveFailed", error.localizedDescription)
        }
    }
}
