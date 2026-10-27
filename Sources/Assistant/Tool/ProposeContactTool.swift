struct ProposeContactTool: ToolPort {
    private let directory: ContactSearchEngine

    init(directory: ContactSearchEngine) {
        self.directory = directory
    }

    var name: String { "create_airtable_kontakt" }
    var access: ToolAccess { .propose }
    var privacy: PrivacyCategory { .contacts }
    var manifestID: String { "AIRTABLE_KONTAKTE_CREATE" }
    var parameters: [ToolParameter] {
        [
            ToolParameter("name", required: true), ToolParameter("organisation"), ToolParameter("email"),
            ToolParameter("telefon"), ToolParameter("adresse"), ToolParameter("kategorie"),
        ]
    }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        guard let name = input.optionalText("name") else { return .failure("assistant.contactDraft.noName") }
        let draft = AirtableContactDraft(
            intent: .create, name: name, organization: input.optionalText("organisation"),
            email: input.optionalText("email"), phone: input.optionalText("telefon"),
            address: input.optionalText("adresse"), category: input.optionalText("kategorie"))
        let summary = [draft.name, draft.email, draft.phone, draft.organization].compactMap { $0 }.joined(separator: " \u{00B7} ")
        var parts: [Phrase] = [.make("assistant.contactDraft.airtable", summary)]
        let matches = DuplicateEngine.matches(
            for: DuplicateEngine.Candidate(name: name, company: draft.organization, email: draft.email, phone: draft.phone),
            in: directory.contacts)
        if matches.isEmpty == false {
            parts.append(.make("assistant.contactDraft.duplicate"))
            parts.append(.join(matches.prefix(3).map(\.detail), "; "))
            parts.append(.make("assistant.contactDraft.duplicateAsk"))
        }
        parts.append(.make("assistant.contactDraft.airtableReady"))
        return ToolResult(.join(parts, ""), cards: [.airtableContactDraft(draft)])
    }
}
