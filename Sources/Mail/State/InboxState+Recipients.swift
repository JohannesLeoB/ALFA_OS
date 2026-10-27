import Design
import Foundation
import Hub

extension InboxState {
    func setPeople(_ id: UUID, _ field: RecipientField, _ people: [Participant]) {
        let text = RecipientEngine.format(people)
        edit(id) { draft in
            switch field {
            case .to: draft.to = text
            case .cc: draft.cc = text
            case .bcc: draft.bcc = text
            }
        }
    }

    public func addRecipient(_ id: UUID, _ field: RecipientField, entry: String) {
        guard let card = draft(id) else { return }
        let parts = PersonName.display(entry)
        let address = parts.address.isEmpty ? entry.trimmingCharacters(in: .whitespacesAndNewlines) : parts.address
        guard !address.isEmpty else { return }
        var people = card.people(field)
        guard !people.contains(where: { $0.address.lowercased() == address.lowercased() }) else { return }
        people.append(Participant(id: people.count, name: parts.name, address: address))
        setPeople(id, field, people)
    }

    public func removeRecipient(_ id: UUID, _ field: RecipientField, at index: Int) {
        guard let card = draft(id) else { return }
        var people = card.people(field)
        guard people.indices.contains(index) else { return }
        people.remove(at: index)
        setPeople(id, field, people)
    }

    public func removeLastRecipient(_ id: UUID, _ field: RecipientField) {
        guard let card = draft(id) else { return }
        removeRecipient(id, field, at: card.people(field).count - 1)
    }

    public func suggestions(_ id: UUID, _ field: RecipientField, query: String) -> [Suggestion] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty, let card = draft(id) else { return [] }
        let have = Set(card.people(field).map { $0.address.lowercased() })
        return Array(pool(own: accountAddress(card.inlet))
            .filter { !have.contains($0.address.lowercased()) && ($0.name + " " + $0.address).lowercased().contains(needle) }
            .prefix(Tokens.Count.contactSuggestions))
    }

    public func setFrom(_ id: UUID, inlet: Inlet.ID) {
        guard let index = drafts.firstIndex(where: { $0.id == id }), accounts.contains(where: { $0.id == inlet }) else { return }
        drafts[index].inlet = inlet
    }

    public var fromChoices: [Inlet] { accounts }

    public var senderSuggestions: [Suggestion] {
        Array(pool(own: selectedAccount?.account.lowercased() ?? "").filter { $0.tag == .sender }
            .prefix(Tokens.Count.senderSuggestions))
    }

    func pool(own: String) -> [Suggestion] {
        var seen = Set(contacts.items.map { $0.address.lowercased() })
        var result = contacts.items.filter { !$0.address.isEmpty }
            .map { Suggestion(name: $0.name, address: $0.address, tag: .contact) }
        func add(_ raw: String) {
            let parts = PersonName.display(raw)
            let address = parts.address.isEmpty ? raw : parts.address
            let key = address.lowercased()
            guard !key.isEmpty, key != own, seen.insert(key).inserted else { return }
            result.append(Suggestion(name: parts.name, address: address, tag: .sender))
        }
        for item in summaries + cards.map(\.summary) {
            add(item.fromRaw)
            for entry in AddressListParser.split(item.ccRaw) { add(entry) }
        }
        return result
    }

    public func contact(_ address: String) -> Contact? {
        contacts.contact(address)
    }

    func saveContact(from messageID: String) -> ToastKind? {
        guard let summary = summary(messageID) else { return nil }
        let party = Self.sender(summary)
        return contacts.save(name: party.name, address: party.address)
    }

    public func saveContact(_ suggestion: Suggestion) -> ToastKind {
        contacts.save(name: suggestion.name.isEmpty ? suggestion.address : suggestion.name, address: suggestion.address)
    }
}
