public struct JournalTool: ToolPort {
    private let journal: JournalStore

    public init(journal: JournalStore) {
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
