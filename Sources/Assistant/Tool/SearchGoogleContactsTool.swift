public struct SearchGoogleContactsTool: ToolPort {
    static let rowLimit = 15

    private let contacts: any GoogleContactsPort

    public init(contacts: any GoogleContactsPort) {
        self.contacts = contacts
    }

    public var name: String { "search_contacts" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .contacts }
    public var manifestID: String { "CONTACTS_QUERY" }
    public var parameters: [ToolParameter] { [ToolParameter("query", required: true)] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("query")
        guard query.isEmpty == false else { return .failure("assistant.common.emptyQuery") }
        do {
            let found = try await contacts.search(query: query)
            guard found.isEmpty == false else { return ToolResult(.make("assistant.contacts.google.empty", query)) }
            return ToolResult(lines: found.prefix(Self.rowLimit).map(Self.row))
        } catch PortFailure.notConnected {
            return .failure("assistant.contacts.google.notConnected")
        } catch {
            return .failure("assistant.contacts.google.failed", PortFailure.detail(of: error))
        }
    }

    static func row(_ contact: GoogleContact) -> Phrase {
        var parts = ["\u{2022} \(contact.displayName)"]
        if let organization = contact.organization, organization.isEmpty == false { parts.append("(\(organization))") }
        if let email = contact.email, email.isEmpty == false { parts.append("\u{00B7} \(email)") }
        if let phone = contact.phone, phone.isEmpty == false { parts.append("\u{00B7} \(phone)") }
        return .raw(parts.joined(separator: " "))
    }
}
