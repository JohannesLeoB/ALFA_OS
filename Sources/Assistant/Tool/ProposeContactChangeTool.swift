public struct ProposeContactChangeTool: ToolPort {
    public init() {}

    public var name: String { "update_airtable_kontakt" }
    public var access: ToolAccess { .propose }
    public var privacy: PrivacyCategory { .contacts }
    public var manifestID: String { "AIRTABLE_KONTAKTE_UPDATE" }
    public var parameters: [ToolParameter] {
        [
            ToolParameter("record_id", required: true), ToolParameter("name"), ToolParameter("organisation"),
            ToolParameter("email"), ToolParameter("telefon"), ToolParameter("adresse"), ToolParameter("kategorie"),
        ]
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        guard let recordID = input.optionalText("record_id") else { return .failure("assistant.contactDraft.noRecord") }
        let name = input.optionalText("name")
        let draft = AirtableContactDraft(
            intent: .update, recordID: recordID, name: name ?? "", organization: input.optionalText("organisation"),
            email: input.optionalText("email"), phone: input.optionalText("telefon"),
            address: input.optionalText("adresse"), category: input.optionalText("kategorie"))
        let line: Phrase = name.map { .make("assistant.contactDraft.change", recordID, $0) }
            ?? .make("assistant.contactDraft.changeUnchanged", recordID)
        return ToolResult(line, cards: [.airtableContactDraft(draft)])
    }
}
