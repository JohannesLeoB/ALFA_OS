import Foundation
import Hub
import ShellCore
import struct AlfaKit.DraftAttachment
import struct AlfaKit.EmailDraft
import struct AlfaServices.MailMessageSummary

public enum RecipientField: String, CaseIterable, Sendable {
    case to
    case cc
    case bcc
}

public struct MailPerson: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let address: String

    public var initials: String { MailNames.initials(name) }

    public var label: String { name.isEmpty ? MailNames.middle(address, limit: SheetValues.personNameLimit) : name }

    public var detail: String { name.isEmpty ? "" : MailNames.middle(address, limit: SheetValues.personAddressLimit) }

    public var full: String { name.isEmpty ? address : name + " · " + address }

    public var first: String {
        name.isEmpty ? MailNames.middle(address, limit: SheetValues.firstNameLimit)
            : String(name.split(whereSeparator: { $0.isWhitespace }).first ?? "")
    }
}

public struct MailSuggestion: Identifiable, Equatable, Sendable {
    public var id: String { address.lowercased() }
    public let name: String
    public let address: String

    public var initials: String { MailNames.initials(name) }

    public var shown: String { MailNames.middle(address, limit: SheetValues.suggestionAddressLimit) }
}

public enum MailRecipients {
    public static func parse(_ raw: String?) -> [MailPerson] {
        MailAddresses.split(raw ?? "").enumerated().map { index, entry in
            let parts = MailNames.display(entry)
            return MailPerson(id: index, name: parts.name, address: parts.address.isEmpty ? entry : parts.address)
        }
    }

    public static func format(_ people: [MailPerson]) -> String? {
        let entries = people.map { person -> String in
            guard !person.name.isEmpty else { return person.address }
            let quoted = person.name.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"" + quoted + "\" <" + person.address + ">"
        }
        return entries.isEmpty ? nil : entries.joined(separator: ", ")
    }

    public static func summary(_ people: [MailPerson]) -> String {
        guard let first = people.first else { return "" }
        if people.count > SheetValues.recipientsInline { return first.first }
        return people.map { $0.name.isEmpty ? MailNames.middle($0.address, limit: SheetValues.personNameLimit) : $0.name }
            .joined(separator: ", ")
    }

    public static func isInline(_ count: Int) -> Bool { count <= SheetValues.recipientsInline }
}

extension MailDraftCard {
    public func people(_ field: RecipientField) -> [MailPerson] {
        switch field {
        case .to: MailRecipients.parse(draft.to)
        case .cc: MailRecipients.parse(draft.cc)
        case .bcc: MailRecipients.parse(draft.bcc)
        }
    }

    public var canSend: Bool {
        switch state {
        case .sending, .queuedInOutbox, .sent: return false
        default: break
        }
        return !people(.to).isEmpty && !draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var needsGrant: Bool {
        guard case .sendFailed(let hint) = state else { return false }
        return hint.kind == .signIn || hint.text == Hint.signInExpiredText
    }

    public var failedToSend: Bool {
        if case .sendFailed = state { return !needsGrant }
        return false
    }
}

extension MailModel {
    public func setPeople(_ id: UUID, _ field: RecipientField, _ people: [MailPerson]) {
        let text = MailRecipients.format(people)
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
        let parts = MailNames.display(entry)
        let address = parts.address.isEmpty ? entry.trimmingCharacters(in: .whitespacesAndNewlines) : parts.address
        guard !address.isEmpty else { return }
        var people = card.people(field)
        guard !people.contains(where: { $0.address.lowercased() == address.lowercased() }) else { return }
        people.append(MailPerson(id: people.count, name: parts.name, address: address))
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

    public func suggestions(_ id: UUID, _ field: RecipientField, query: String) -> [MailSuggestion] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty, let card = draft(id) else { return [] }
        let have = Set(card.people(field).map { $0.address.lowercased() })
        let own = engineAccount(card.inlet)
        var seen = Set<String>()
        var pool: [MailSuggestion] = []
        func add(_ raw: String) {
            let parts = MailNames.display(raw)
            let address = parts.address.isEmpty ? raw : parts.address
            let key = address.lowercased()
            guard !key.isEmpty, key != own, !have.contains(key), seen.insert(key).inserted else { return }
            pool.append(MailSuggestion(name: parts.name, address: address))
        }
        let known = summaries + cards.map(\.summary)
        for item in known {
            add(item.fromRaw)
            for entry in MailAddresses.split(item.toRaw + "," + item.ccRaw) { add(entry) }
        }
        return Array(pool.filter { ($0.name + " " + $0.address).lowercased().contains(needle) }
            .prefix(Design.Count.contactSuggestions))
    }

    public func setFrom(_ id: UUID, inlet: Inlet.ID) {
        guard let index = drafts.firstIndex(where: { $0.id == id }), accounts.contains(where: { $0.id == inlet }) else { return }
        drafts[index].inlet = inlet
    }

    public var fromChoices: [Inlet] { accounts }
}

extension MailModel {
    public func attach(_ id: UUID, filename: String, mimeType: String, data: Data) {
        edit(id) { $0.attachments.append(DraftAttachment(filename: filename, mimeType: mimeType, data: data)) }
    }

    public func removeAttachment(_ id: UUID, at index: Int) {
        edit(id) { draft in
            guard draft.attachments.indices.contains(index) else { return }
            draft.attachments.remove(at: index)
        }
    }
}
