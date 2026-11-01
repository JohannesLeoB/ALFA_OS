import Foundation

public struct CreateNoteTool: ToolPort {
    private let notes: any NotesPort

    public init(notes: any NotesPort) {
        self.notes = notes
    }

    public var name: String { "create_note" }
    public var access: ToolAccess { .write }
    public var privacy: PrivacyCategory { .notes }
    public var manifestID: String { "ASSISTANT_NOTES" }
    public var activityKey: String { "assistant.activity.notes" }
    public var parameters: [ToolParameter] { [ToolParameter("text", required: true), ToolParameter("trotzdem")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let text = input.text("text")
        guard text.isEmpty == false else { return .failure("assistant.notes.noText") }
        do {
            if input.flag("trotzdem") == false, let existing = NoteDuplicateEngine.existing(for: text, in: try await notes.all()) {
                return ToolResult(.make("assistant.notes.duplicate", existing.ref, existing.body))
            }
            let note = try await notes.create(text, projectID: scope.projectID)
            var parts: [Phrase] = [.make("assistant.notes.created", note.ref)]
            if let project = note.projectID { parts.append(.make("assistant.common.inProject", project)) }
            parts.append(.raw(": \(note.body)"))
            return ToolResult(.join(parts, ""))
        } catch {
            return .failure("assistant.notes.saveFailed", error.localizedDescription)
        }
    }
}

public struct ListNotesTool: ToolPort {
    private let notes: any NotesPort

    public init(notes: any NotesPort) {
        self.notes = notes
    }

    public var name: String { "list_notes" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .notes }
    public var manifestID: String { "ASSISTANT_NOTES" }
    public var activityKey: String { "assistant.activity.notes" }
    public var parameters: [ToolParameter] { [ToolParameter("alle")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        do {
            let all = input.flag("alle") || scope.projectID == nil
            let found = all ? try await notes.all() : try await notes.scoped(to: scope.projectID)
            guard found.isEmpty == false else { return ToolResult(.make("assistant.notes.none")) }
            return ToolResult(lines: found.map { note in
                var parts: [Phrase] = [.raw("\u{2022} [\(note.ref)] \(note.body)")]
                if let project = note.projectID { parts.append(.make("assistant.common.projectTag", project)) }
                parts.append(.raw(" (\(ListingEngine.format(note.updatedAt, "dd.MM.yy HH:mm")))"))
                return .join(parts, "")
            })
        } catch {
            return .failure("assistant.notes.loadFailed", error.localizedDescription)
        }
    }
}

public struct UpdateNoteTool: ToolPort {
    private let notes: any NotesPort

    public init(notes: any NotesPort) {
        self.notes = notes
    }

    public var name: String { "update_note" }
    public var access: ToolAccess { .write }
    public var privacy: PrivacyCategory { .notes }
    public var manifestID: String { "ASSISTANT_NOTES" }
    public var activityKey: String { "assistant.activity.notes" }
    public var parameters: [ToolParameter] { [ToolParameter("note", required: true), ToolParameter("text", required: true)] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("note")
        let text = input.text("text")
        guard query.isEmpty == false, text.isEmpty == false else { return .failure("assistant.notes.needBoth") }
        do {
            guard let note = try await notes.update(matching: query, newBody: text, scopedTo: scope.projectID) else {
                return .failure("assistant.notes.notFound", query)
            }
            return ToolResult(.make("assistant.notes.updated", note.ref, note.body))
        } catch {
            return .failure("assistant.notes.updateFailed", error.localizedDescription)
        }
    }
}

public struct DeleteNoteTool: ToolPort {
    private let notes: any NotesPort

    public init(notes: any NotesPort) {
        self.notes = notes
    }

    public var name: String { "delete_note" }
    public var access: ToolAccess { .write }
    public var privacy: PrivacyCategory { .notes }
    public var manifestID: String { "ASSISTANT_NOTES" }
    public var activityKey: String { "assistant.activity.notes" }
    public var parameters: [ToolParameter] { [ToolParameter("note", required: true)] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("note")
        guard query.isEmpty == false else { return .failure("assistant.notes.whichNote") }
        do {
            guard let note = try await notes.delete(matching: query, scopedTo: scope.projectID) else {
                return .failure("assistant.notes.notFound", query)
            }
            return ToolResult(.make("assistant.notes.deleted", note.ref, note.body))
        } catch {
            return .failure("assistant.notes.deleteFailed", error.localizedDescription)
        }
    }
}

public struct ListTodosTool: ToolPort {
    private let todos: any TodosPort

    public init(todos: any TodosPort) {
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

public struct CreateTodoTool: ToolPort {
    private let todos: any TodosPort
    private let alarm: any AlarmPort

    public init(todos: any TodosPort, alarm: any AlarmPort) {
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

public struct CompleteTodoTool: ToolPort {
    private let todos: any TodosPort
    private let alarm: any AlarmPort

    public init(todos: any TodosPort, alarm: any AlarmPort) {
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

public struct DeleteTodoTool: ToolPort {
    private let todos: any TodosPort
    private let alarm: any AlarmPort

    public init(todos: any TodosPort, alarm: any AlarmPort) {
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

public struct JournalTool: ToolPort {
    private let journal: any JournalPort

    public init(journal: any JournalPort) {
        self.journal = journal
    }

    public var name: String { "log_friction_point" }
    public var access: ToolAccess { .write }
    public var privacy: PrivacyCategory { .chat }
    public var documented: Bool { false }
    public var parameters: [ToolParameter] { [ToolParameter("art", required: true), ToolParameter("text", required: true)] }

    static func kind(from raw: String?) -> JournalEntry.Kind {
        switch raw?.lowercased() {
        case "kann_nicht_lesen", "kannnichtlesen": .cannotRead
        case "widerspruch": .contradiction
        case "fehlende_info", "fehlendeinfo": .missingInfo
        default: .other
        }
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let text = input.text("text")
        guard text.isEmpty == false else { return .failure("assistant.journal.noText") }
        do {
            try await journal.append(JournalEntry(projectID: scope.projectID, kind: Self.kind(from: input.optionalText("art")), text: text))
            return ToolResult(.make("assistant.journal.logged"))
        } catch {
            return .failure("assistant.journal.failed", error.localizedDescription)
        }
    }
}
