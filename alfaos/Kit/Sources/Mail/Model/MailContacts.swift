import Foundation
import ShellCore

public struct MailContact: Identifiable, Equatable, Sendable, Codable {
    public static let storageKey = "mail.contacts"

    public var id: String
    public var name: String
    public var address: String

    static func load(from defaults: UserDefaults?) -> [MailContact] {
        guard let data = defaults?.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([MailContact].self, from: data)) ?? []
    }

    static func store(_ contacts: [MailContact], in defaults: UserDefaults?) {
        guard let defaults else { return }
        defaults.set(try? JSONEncoder().encode(contacts), forKey: storageKey)
    }
}

public enum MailSuggestionTag: Equatable, Sendable {
    case contact
    case sender

    public var key: String { self == .contact ? "mail.suggest.contact" : "mail.suggest.sender" }
}

extension MailModel {
    public func contact(_ address: String) -> MailContact? {
        contacts.first { $0.address.lowercased() == address.lowercased() }
    }

    public func saveContact(name: String, address: String) -> MailToastKind {
        let shown = name.isEmpty ? address : name
        if contact(address) != nil { return .contactExists(shown) }
        contacts.append(MailContact(id: UUID().uuidString, name: name, address: address))
        return .contactSaved(shown)
    }

    public func saveContact(from messageID: String) -> MailToastKind? {
        guard let summary = summary(messageID) else { return nil }
        let party = Self.sender(summary)
        return saveContact(name: party.name, address: party.address)
    }

    public func saveContact(_ suggestion: MailSuggestion) -> MailToastKind {
        saveContact(name: suggestion.name.isEmpty ? suggestion.address : suggestion.name, address: suggestion.address)
    }

    public func editContact(_ id: String, name: String? = nil, address: String? = nil) {
        guard let index = contacts.firstIndex(where: { $0.id == id }) else { return }
        if let name { contacts[index].name = name }
        if let address { contacts[index].address = address }
    }

    public func removeContact(_ id: String) -> MailToastKind {
        contacts.removeAll { $0.id == id }
        if contactEdit == id { contactEdit = nil }
        return .contactRemoved
    }

    public func addContact() {
        let added = MailContact(id: UUID().uuidString, name: "", address: "")
        contacts.append(added)
        contactEdit = added.id
    }

    public var senderSuggestions: [MailSuggestion] {
        Array(pool(own: selectedAccount?.account.lowercased() ?? "").filter { $0.tag == .sender }
            .prefix(Design.Count.senderSuggestions))
    }

    func pool(own: String) -> [MailSuggestion] {
        var seen = Set(contacts.map { $0.address.lowercased() })
        var result = contacts.filter { !$0.address.isEmpty }
            .map { MailSuggestion(name: $0.name, address: $0.address, tag: .contact) }
        func add(_ raw: String) {
            let parts = MailNames.display(raw)
            let address = parts.address.isEmpty ? raw : parts.address
            let key = address.lowercased()
            guard !key.isEmpty, key != own, seen.insert(key).inserted else { return }
            result.append(MailSuggestion(name: parts.name, address: address, tag: .sender))
        }
        for item in summaries + cards.map(\.summary) {
            add(item.fromRaw)
            for entry in MailAddresses.split(item.ccRaw) { add(entry) }
        }
        return result
    }
}

public enum MailDraftStatus: Equatable, Sendable {
    case sending
    case saved
    case recipientMissing
    case subjectMissing
    case sendFailed

    public var key: String {
        switch self {
        case .sending: "mail.draft.sending"
        case .saved: "mail.draft.saved"
        case .recipientMissing: "mail.toast.recipientMissing"
        case .subjectMissing: "mail.draft.subjectMissing"
        case .sendFailed: "mail.draft.sendFailed"
        }
    }

    public var failed: Bool { self == .sendFailed }
}

extension MailDraftCard {
    public var status: MailDraftStatus? {
        switch state {
        case .sending, .queuedInOutbox: return .sending
        case .saved: return .saved
        default: break
        }
        if people(.to).isEmpty { return .recipientMissing }
        if draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .subjectMissing }
        return failedToSend ? .sendFailed : nil
    }
}
