struct ContactSearchEngine: Sendable {
    let contacts: [Contact]

    init(contacts: [Contact]) {
        self.contacts = contacts
    }

    func search(_ query: String, limit: Int = 8) -> [Contact] {
        let lowered = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard lowered.isEmpty == false else { return [] }
        let ranked = contacts.filter { $0.matches(lowered) }.sorted { rank($0, lowered) < rank($1, lowered) }
        return Array(ranked.prefix(limit))
    }

    private func rank(_ contact: Contact, _ query: String) -> Int {
        let name = contact.name.lowercased()
        if name == query { return 0 }
        if name.hasPrefix(query) { return 1 }
        return 2
    }
}
