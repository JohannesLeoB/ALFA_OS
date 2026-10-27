public struct ListNotesTool: ToolPort {
    private let notes: NoteStore

    public init(notes: NoteStore) {
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
