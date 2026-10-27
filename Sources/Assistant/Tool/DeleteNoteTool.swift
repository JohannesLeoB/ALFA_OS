public struct DeleteNoteTool: ToolPort {
    private let notes: NoteStore

    public init(notes: NoteStore) {
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
