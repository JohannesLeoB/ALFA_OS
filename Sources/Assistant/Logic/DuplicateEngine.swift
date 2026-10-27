import Foundation

enum DuplicateEngine {
    struct Candidate: Sendable, Equatable {
        var name: String?
        var company: String?
        var email: String?
        var phone: String?
    }

    static func matches(for candidate: Candidate, in contacts: [Contact]) -> [DuplicateMatch] {
        var found: [DuplicateMatch] = []
        if let mail = clean(candidate.email)?.lowercased() {
            for contact in contacts where contact.email?.lowercased() == mail {
                found.append(DuplicateMatch(contactID: contact.project ?? contact.id, name: contact.name, reason: .email,
                                            detail: .make("assistant.duplicate.email", mail, contact.name)))
            }
        }
        if let phone = clean(candidate.phone).map(digits), phone.isEmpty == false {
            for contact in contacts where contact.phone.map(digits) == phone {
                found.append(DuplicateMatch(contactID: contact.project ?? contact.id, name: contact.name, reason: .phone,
                                            detail: .make("assistant.duplicate.phone", contact.name)))
            }
        }
        if let name = clean(candidate.name).map(normalize) {
            for contact in contacts where normalize(contact.name) == name {
                found.append(DuplicateMatch(contactID: contact.project ?? contact.id, name: contact.name, reason: .name,
                                            detail: .make("assistant.duplicate.name", contact.name)))
            }
        }
        if let company = clean(candidate.company).map(normalize) {
            for contact in contacts where contact.organization.map(normalize) == company {
                found.append(DuplicateMatch(contactID: contact.project ?? contact.id, name: contact.name, reason: .company,
                                            detail: .make("assistant.duplicate.company", contact.organization ?? contact.name)))
            }
        }
        let rank: [DuplicateMatch.Reason: Int] = [.email: 0, .phone: 1, .name: 2, .company: 3]
        var seen = Set<String>()
        return found
            .sorted { (rank[$0.reason] ?? 9) < (rank[$1.reason] ?? 9) }
            .filter { seen.insert($0.id).inserted }
    }

    static func clean(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else { return nil }
        return trimmed
    }

    static func digits(_ value: String) -> String { String(value.filter(\.isNumber)) }

    static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct DuplicateMatch: Sendable, Equatable, Identifiable {
    enum Reason: String, Sendable, Equatable {
        case email, phone, name, company
    }

    let contactID: String
    let name: String
    let reason: Reason
    let detail: Phrase

    var id: String { contactID + ":" + reason.rawValue }

    init(contactID: String, name: String, reason: Reason, detail: Phrase) {
        self.contactID = contactID
        self.name = name
        self.reason = reason
        self.detail = detail
    }
}
