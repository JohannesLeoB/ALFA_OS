public struct UpdateNoteTool: ToolPort {
    private let notes: NoteStore

    public init(notes: NoteStore) {
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
