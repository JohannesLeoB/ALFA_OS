import Foundation

enum ProvenanceEngine {
    enum Field: String, Sendable, Equatable {
        case to, cc, bcc, email, phone

        var textKey: String { "assistant.field." + rawValue }
    }

    enum ValueKind: String, Sendable, Equatable {
        case email
        case phone
    }

    struct UngroundedValue: Sendable, Equatable {
        let kind: ValueKind
        let field: Field
        let value: String
    }

    struct Verdict: Sendable, Equatable {
        var ungrounded: [UngroundedValue] = []

        var isGrounded: Bool { ungrounded.isEmpty }
    }

    struct Evidence: Sendable, Equatable {
        let lowercased: String
        let digitsOnly: String

        init(_ proofs: [String]) {
            let joined = proofs.joined(separator: "\n")
            self.lowercased = joined.lowercased()
            self.digitsOnly = joined.filter { $0.isNumber }
        }
    }

    struct Source: Sendable, Equatable {
        let label: String
        let text: String
    }

    struct Hit: Sendable, Equatable {
        let kind: ValueKind
        let field: Field
        let value: String
        let source: String
    }

    struct Subject {
        let emails: [(Field, String?)]
        let phone: String?
    }

    static func subject(_ draft: MailDraft) -> Subject {
        Subject(emails: [(.to, draft.to), (.cc, draft.cc), (.bcc, draft.bcc)], phone: nil)
    }

    static func subject(_ draft: ContactDraft) -> Subject {
        Subject(emails: [(.email, draft.email)], phone: draft.phone)
    }

    static func subject(_ draft: AirtableContactDraft) -> Subject {
        Subject(emails: [(.email, draft.email)], phone: draft.phone)
    }

    static func check(_ subject: Subject, evidence: Evidence) -> Verdict {
        var open: [UngroundedValue] = []
        for (field, raw) in subject.emails {
            guard let raw else { continue }
            for address in addresses(in: raw) where isEmailProven(address, evidence) == false {
                open.append(UngroundedValue(kind: .email, field: field, value: address))
            }
        }
        if let phone = subject.phone, isPhoneProven(phone, evidence) == false {
            open.append(UngroundedValue(kind: .phone, field: .phone, value: phone))
        }
        return Verdict(ungrounded: open)
    }

    static func provenance(_ subject: Subject, sources: [Source]) -> [Hit] {
        var hits: [Hit] = []
        for (field, raw) in subject.emails {
            guard let raw else { continue }
            for address in addresses(in: raw) {
                if let source = sources.first(where: { isEmailProven(address, Evidence([$0.text])) })?.label {
                    hits.append(Hit(kind: .email, field: field, value: address, source: source))
                }
            }
        }
        if let phone = subject.phone,
           let source = sources.first(where: { isPhoneProven(phone, Evidence([$0.text])) })?.label {
            hits.append(Hit(kind: .phone, field: .phone, value: phone, source: source))
        }
        return hits
    }

    static func provenanceLabel(_ hits: [Hit], text: any TextPort) -> String? {
        guard hits.isEmpty == false else { return nil }
        let parts = hits.map { "\($0.value) \u{2190} \($0.source)" }.joined(separator: ", ")
        return text.text("assistant.gate.proven", [parts])
    }

    static func warnLabel(_ verdict: Verdict, text: any TextPort) -> String {
        let values = verdict.ungrounded
            .map { "\($0.value) (\(text.text($0.field.textKey, [])))" }
            .joined(separator: ", ")
        return text.text("assistant.gate.warn", [values])
    }

    static func modelHint(_ verdict: Verdict, text: any TextPort) -> String {
        let values = verdict.ungrounded
            .map { value in
                text.text("assistant.gate.hintValue", [value.kind.rawValue, value.value, text.text(value.field.textKey, [])])
            }
            .joined(separator: "; ")
        return "\n\n" + text.text("assistant.gate.hint", [values])
    }

    static func isEmailProven(_ email: String, _ evidence: Evidence) -> Bool {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return true }
        return evidence.lowercased.contains(normalized)
    }

    static func isPhoneProven(_ phone: String, _ evidence: Evidence) -> Bool {
        let digits = phone.filter { $0.isNumber }
        guard digits.count >= 5 else { return true }
        let needle = String(digits.suffix(min(digits.count, 7)))
        return evidence.digitsOnly.contains(needle)
    }

    static func addresses(in text: String) -> [String] {
        let pattern = "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let area = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: area).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}
