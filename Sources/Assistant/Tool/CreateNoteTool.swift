public struct CreateNoteTool: ToolPort {
    private let notes: NoteStore

    public init(notes: NoteStore) {
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
