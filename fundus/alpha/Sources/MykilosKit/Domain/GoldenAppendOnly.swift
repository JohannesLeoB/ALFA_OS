import Foundation

public struct GoldenFieldChange: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        case fill
        case supersede
    }

    public let field: String
    public let previous: String
    public let next: String
    public let kind: Kind

    public var id: String { field }

    public init(field: String, previous: String, next: String) {
        self.field = field
        self.previous = previous
        self.next = next
        self.kind = previous.isEmpty ? .fill : .supersede
    }
}

public enum GoldenAppendOnly {
    public static let historyField = "Verlauf"

    public static func changes(existing: StudioContact, proposed: MailSignatureContact) -> [GoldenFieldChange] {
        var out: [GoldenFieldChange] = []
        func compare(_ label: String, _ old: String?, _ new: String?) {
            let a = (old ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let b = (new ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard b.isEmpty == false else { return }
            guard a.caseInsensitiveCompare(b) != .orderedSame else { return }
            out.append(GoldenFieldChange(field: label, previous: a, next: b))
        }
        compare("Firma / Name", existing.organisation ?? existing.name, proposed.organisation)
        compare("E-Mail", existing.email, proposed.email)
        compare("Telefon", existing.telefon, proposed.telefon)
        compare("Straße", existing.strasse ?? existing.adresse, proposed.adresse)
        return out
    }

    public static func historyEntry(for changes: [GoldenFieldChange], on day: String, source: String) -> String {
        let superseded = changes.filter { $0.kind == .supersede }
        guard superseded.isEmpty == false else { return "" }
        return superseded
            .map { "\(day) | \($0.field) | zuvor: \($0.previous) | Quelle: \(source)" }
            .joined(separator: "\n")
    }

    public static func appended(history existing: String?, entry: String) -> String {
        let current = (existing ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard entry.isEmpty == false else { return current }
        guard current.isEmpty == false else { return entry }
        return current + "\n" + entry
    }

    public static func belongsInMasterRecord(_ contact: StudioContact) -> Bool {
        (contact.customerNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    public static func continuation(of existing: StudioContact,
                                    proposed: MailSignatureContact,
                                    day: String,
                                    source: String) -> AirtableContactDraft {
        var draft = AirtableContactDraft(
            intent: .update,
            recordID: existing.id,
            name: proposed.name,
            organisation: proposed.organisation,
            email: proposed.email,
            telefon: proposed.telefon,
            adresse: proposed.adresse,
            source: existing.source)
        draft.vollerFeldsatz = true
        if belongsInMasterRecord(existing) {
            let entry = historyEntry(for: changes(existing: existing, proposed: proposed),
                                     on: day, source: source)
            draft.history = appended(history: existing.history, entry: entry)
        }
        return draft
    }

    public static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
