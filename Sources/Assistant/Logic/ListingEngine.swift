import Foundation

enum ListingEngine {
    static let rowLimit = 40
    static let timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current

    static func money(_ value: Double?) -> String? {
        guard let value else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSNumber)
    }

    static func wholeNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }

    static func format(_ date: Date, _ pattern: String, locale: String = "de_DE") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    static func day(_ date: Date) -> String { format(date, "dd.MM.yyyy") }

    static func shortDay(_ date: Date) -> String { format(date, "dd.MM.yy") }

    static func dateTime(_ date: Date) -> String { format(date, "EEE d. MMM yyyy, HH:mm") }

    static func clip(_ rows: [Phrase], total: Int) -> [Phrase] {
        guard total > rows.count else { return rows }
        return rows + [.make("assistant.list.more", String(total - rows.count))]
    }

    static func hours(_ seconds: Int) -> String {
        String(format: "%.1f", Double(seconds) / 3600)
    }

    static func duration(_ seconds: Int) -> String {
        if seconds >= 3600 { return String(format: "%.1f h", Double(seconds) / 3600) }
        return "\(Int((Double(seconds) / 60).rounded())) min"
    }
}

struct CustomerSearchEngine: Sendable {
    static let hitLimit = 15
    static let exampleLimit = 8

    let customers: [CustomerEntry]
    let projectCounts: [String: Int]

    init(customers: [CustomerEntry], projectCounts: [String: Int] = [:]) {
        self.customers = customers
        self.projectCounts = projectCounts
    }

    func lookup(_ query: String) -> [CustomerEntry] {
        let tokens = query.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init).filter { $0.count >= 2 }
        guard tokens.isEmpty == false else { return [] }
        func matches(_ haystack: String) -> Bool {
            let lowered = haystack.lowercased()
            return tokens.contains { lowered.contains($0) }
        }
        return customers
            .filter { matches($0.name) || matches($0.number) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            .prefix(Self.hitLimit)
            .map { $0 }
    }

    func overview() -> [Phrase] {
        let examples = customers
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            .prefix(Self.exampleLimit).map(\.name)
        var lines: [Phrase] = [.make("assistant.customers.overview", String(customers.count))]
        if examples.isEmpty == false { lines.append(.make("assistant.customers.examples", examples.joined(separator: ", "))) }
        return lines
    }

    func describe(_ customer: CustomerEntry) -> Phrase {
        let count = projectCounts[customer.number] ?? 0
        var parts: [Phrase] = [.make("assistant.customers.row", customer.name, customer.number)]
        if count > 0 {
            parts.append(.make(count == 1 ? "assistant.customers.projectOne" : "assistant.customers.projectMany", String(count)))
        }
        return .join(parts, " ")
    }
}

struct CustomerEntry: Sendable, Equatable {
    let number: String
    let name: String

    init(number: String, name: String) {
        self.number = number
        self.name = name
    }
}

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

struct ProjectSearchEngine: Sendable {
    let entries: [ProjectEntry]

    init(entries: [ProjectEntry]) {
        self.entries = entries
    }

    func filter(_ query: String) -> [ProjectEntry] {
        let lowered = query.lowercased()
        guard lowered.isEmpty == false else { return entries }
        return entries.filter {
            $0.projectNumber.lowercased().contains(lowered)
                || $0.title.lowercased().contains(lowered)
                || ($0.customerName?.lowercased().contains(lowered) ?? false)
        }
    }

    func resolve(_ query: String) -> ProjectEntry? {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard lowered.isEmpty == false else { return nil }
        if let exact = entries.first(where: { $0.projectNumber.lowercased() == lowered }) { return exact }
        return entries.first { entry in
            entry.projectNumber.lowercased().contains(lowered)
                || entry.title.lowercased().contains(lowered)
                || (entry.customerName?.lowercased().contains(lowered) ?? false)
        }
    }
}

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

enum NoteDuplicateEngine {
    static let threshold = 0.8

    static func words(_ text: String) -> Set<String> {
        Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false })
    }

    static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let left = words(lhs)
        let right = words(rhs)
        guard left.isEmpty == false, right.isEmpty == false else { return 0 }
        return Double(left.intersection(right).count) / Double(left.union(right).count)
    }

    static func existing(for text: String, in notes: [Note]) -> Note? {
        notes
            .map { ($0, similarity(text, $0.body)) }
            .filter { $0.1 >= threshold }
            .max { $0.1 < $1.1 }?.0
    }
}
