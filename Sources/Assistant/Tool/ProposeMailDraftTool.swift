public struct ProposeMailDraftTool: ToolPort {
    public init() {}

    public var name: String { "create_draft" }
    public var access: ToolAccess { .propose }
    public var privacy: PrivacyCategory { .mail }
    public var manifestID: String { "GMAIL_DRAFT_CREATE" }
    public var parameters: [ToolParameter] {
        [ToolParameter("betreff", required: true), ToolParameter("text", required: true), ToolParameter("an")]
    }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let subject = input.text("betreff")
        let body = input.text("text")
        guard subject.isEmpty == false || body.isEmpty == false else { return .failure("assistant.draft.needContent") }
        let recipient = input.optionalText("an")
        let draft = MailDraft(to: recipient, subject: subject, body: body)
        let line: Phrase = recipient.map { .make("assistant.draft.readyTo", subject, $0) } ?? .make("assistant.draft.ready", subject)
        return ToolResult(line, cards: [.mailDraft(draft)])
    }
}
