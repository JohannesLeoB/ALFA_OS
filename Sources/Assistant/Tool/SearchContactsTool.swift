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

struct LookupCustomerTool: ToolPort {
    static let overviewWords: Set<String> = ["\u{FC}bersicht", "overview", "alle", "liste"]

    private let customers: CustomerSearchEngine

    init(customers: CustomerSearchEngine) {
        self.customers = customers
    }

    var name: String { "lookup_kunde" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .contacts }
    var manifestID: String { "AIRTABLE_KUNDEN_LOOKUP" }
    var documented: Bool { false }
    var parameters: [ToolParameter] { [ToolParameter("query")] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let query = input.text("query")
        if query.isEmpty || Self.overviewWords.contains(query.lowercased()) {
            return ToolResult(lines: customers.overview())
        }
        let hits = customers.lookup(query)
        guard hits.isEmpty == false else { return ToolResult(.make("assistant.customers.noHits", query)) }
        return ToolResult(lines: hits.map(customers.describe))
    }
}
