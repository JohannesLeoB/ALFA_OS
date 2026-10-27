struct SearchContactsTool: ToolPort {
    static let searchLimit = 10
    static let listLimit = 50

    private let directory: ContactSearchEngine

    init(directory: ContactSearchEngine) {
        self.directory = directory
    }

    var name: String { "lookup_kontakt" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .contacts }
    var manifestID: String { "AIRTABLE_KONTAKTE_LOOKUP" }
    var parameters: [ToolParameter] { [ToolParameter("query"), ToolParameter("kategorie")] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("query")
        let category = input.text("kategorie").lowercased()
        if query.isEmpty { return list(category: category) }
        var hits = directory.search(query, limit: Self.searchLimit)
        if category.isEmpty == false { hits = hits.filter { ($0.category ?? "").lowercased().contains(category) } }
        guard hits.isEmpty == false else { return ToolResult(.make("assistant.contacts.noHits", query)) }
        return ToolResult(lines: hits.map { Self.row($0, withID: true) })
    }

    private func list(category: String) -> ToolResult {
        var contacts = directory.contacts
        if category.isEmpty == false { contacts = contacts.filter { ($0.category ?? "").lowercased().contains(category) } }
        guard contacts.isEmpty == false else {
            return ToolResult(category.isEmpty ? .make("assistant.contacts.listEmpty") : .make("assistant.contacts.listEmptyCategory", category))
        }
        var lines: [Phrase] = [.make("assistant.contacts.listHeader", String(contacts.count))]
        lines += contacts.prefix(Self.listLimit).map { Self.row($0, withID: false) }
        if contacts.count > Self.listLimit { lines.append(.make("assistant.list.moreContacts", String(contacts.count - Self.listLimit))) }
        return ToolResult(lines: lines)
    }

    static func row(_ contact: Contact, withID: Bool) -> Phrase {
        var head = "\u{2022} \(contact.name)"
        if let organization = contact.organization { head += " \u{00B7} \(organization)" }
        if let category = contact.category { head += " [\(category)]" }
        var details: [Phrase] = []
        if withID { details.append(.raw("ID: \(contact.id)")) }
        if let phone = contact.phone { details.append(.raw("\u{260E} \(phone)")) }
        if let email = contact.email { details.append(.raw("\u{2709} \(email)")) }
        if let address = contact.address { details.append(.raw("\u{2302} \(address)")) }
        if withID, let project = contact.project { details.append(.make("assistant.contacts.project", project)) }
        guard details.isEmpty == false else { return .raw(head) }
        return .join([.raw(head), .join(details, " \u{00B7} ")], "\n  ")
    }
}
