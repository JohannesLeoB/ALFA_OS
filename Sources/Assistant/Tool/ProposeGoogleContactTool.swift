public struct ProposeGoogleContactTool: ToolPort {
    public init() {}

    public var name: String { "create_contact" }
    public var access: ToolAccess { .propose }
    public var privacy: PrivacyCategory { .contacts }
    public var manifestID: String { "CONTACTS_CREATE" }
    public var parameters: [ToolParameter] {
        [
            ToolParameter("vorname", required: true), ToolParameter("nachname"), ToolParameter("email"),
            ToolParameter("telefon"), ToolParameter("firma"),
        ]
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        guard let given = input.optionalText("vorname") ?? input.optionalText("name") else {
            return .failure("assistant.contactDraft.noName")
        }
        let draft = ContactDraft(givenName: given, familyName: input.optionalText("nachname"),
                                 email: input.optionalText("email"), phone: input.optionalText("telefon"),
                                 organization: input.optionalText("firma"))
        let summary = [draft.displayName, draft.email, draft.phone, draft.organization].compactMap { $0 }.joined(separator: " \u{00B7} ")
        return ToolResult(.make("assistant.contactDraft.google", summary), cards: [.contactDraft(draft)])
    }
}
