import Foundation

public enum GroundingGate {
    public struct UngroundedValue: Sendable, Equatable {
        public enum Kind: String, Sendable, Equatable {
            case email
            case telefon
        }
        public var kind: Kind

        public var feld: String

        public var value: String

        public init(kind: Kind, feld: String, value: String) {
            self.kind = kind
            self.feld = feld
            self.value = value
        }
    }

    public struct Verdict: Sendable, Equatable {
        public var ungrounded: [UngroundedValue]
        public var isGrounded: Bool { ungrounded.isEmpty }

        public init(ungrounded: [UngroundedValue] = []) {
            self.ungrounded = ungrounded
        }
    }

    public struct Evidence: Sendable, Equatable {
        let kleingeschrieben: String
        let nurZiffern: String

        public init(_ belege: [String]) {
            let zusammen = belege.joined(separator: "\n")
            self.kleingeschrieben = zusammen.lowercased()
            self.nurZiffern = zusammen.filter { $0.isNumber }
        }
    }

    public static func pruefe(_ draft: EmailDraft, evidence: Evidence) -> Verdict {
        var offen: [UngroundedValue] = []
        let felder: [(String, String?)] = [
            ("Empfänger (An)", draft.to),
            ("CC", draft.cc),
            ("BCC", draft.bcc)
        ]
        for (feld, roh) in felder {
            guard let roh else { continue }
            for adresse in emailAdressen(in: roh) where istEmailBelegt(adresse, evidence) == false {
                offen.append(UngroundedValue(kind: .email, feld: feld, value: adresse))
            }
        }
        return Verdict(ungrounded: offen)
    }

    public static func pruefe(_ draft: ContactDraft, evidence: Evidence) -> Verdict {
        var offen: [UngroundedValue] = []
        if let email = draft.email {
            for adresse in emailAdressen(in: email) where istEmailBelegt(adresse, evidence) == false {
                offen.append(UngroundedValue(kind: .email, feld: "E-Mail", value: adresse))
            }
        }
        if let telefon = draft.phone, istTelefonBelegt(telefon, evidence) == false {
            offen.append(UngroundedValue(kind: .telefon, feld: "Telefon", value: telefon))
        }
        return Verdict(ungrounded: offen)
    }

    public static func pruefe(_ draft: AirtableContactDraft, evidence: Evidence) -> Verdict {
        var offen: [UngroundedValue] = []
        if let email = draft.email {
            for adresse in emailAdressen(in: email) where istEmailBelegt(adresse, evidence) == false {
                offen.append(UngroundedValue(kind: .email, feld: "E-Mail", value: adresse))
            }
        }
        if let telefon = draft.telefon, istTelefonBelegt(telefon, evidence) == false {
            offen.append(UngroundedValue(kind: .telefon, feld: "Telefon", value: telefon))
        }
        return Verdict(ungrounded: offen)
    }

    public struct BelegQuelle: Sendable, Equatable {
        public var source: String

        public var text: String

        public init(source: String, text: String) {
            self.source = source
            self.text = text
        }
    }

    public struct ProvenanceHit: Sendable, Equatable {
        public var kind: UngroundedValue.Kind
        public var feld: String
        public var value: String

        public var source: String

        public init(kind: UngroundedValue.Kind, feld: String, value: String, source: String) {
            self.kind = kind
            self.feld = feld
            self.value = value
            self.source = source
        }
    }

    static func quelleFuerEmail(_ adresse: String, _ belege: [BelegQuelle]) -> String? {
        belege.first { istEmailBelegt(adresse, Evidence([$0.text])) }?.source
    }

    static func quelleFuerTelefon(_ telefon: String, _ belege: [BelegQuelle]) -> String? {
        belege.first { istTelefonBelegt(telefon, Evidence([$0.text])) }?.source
    }

    public static func provenance(_ draft: EmailDraft, belege: [BelegQuelle]) -> [ProvenanceHit] {
        var hits: [ProvenanceHit] = []
        let felder: [(String, String?)] = [
            ("Empfänger (An)", draft.to),
            ("CC", draft.cc),
            ("BCC", draft.bcc)
        ]
        for (feld, roh) in felder {
            guard let roh else { continue }
            for adresse in emailAdressen(in: roh) {
                if let source = quelleFuerEmail(adresse, belege) {
                    hits.append(ProvenanceHit(kind: .email, feld: feld, value: adresse, source: source))
                }
            }
        }
        return hits
    }

    public static func provenance(_ draft: ContactDraft, belege: [BelegQuelle]) -> [ProvenanceHit] {
        var hits: [ProvenanceHit] = []
        if let email = draft.email {
            for adresse in emailAdressen(in: email) {
                if let source = quelleFuerEmail(adresse, belege) {
                    hits.append(ProvenanceHit(kind: .email, feld: "E-Mail", value: adresse, source: source))
                }
            }
        }
        if let telefon = draft.phone, let source = quelleFuerTelefon(telefon, belege) {
            hits.append(ProvenanceHit(kind: .telefon, feld: "Telefon", value: telefon, source: source))
        }
        return hits
    }

    public static func provenance(_ draft: AirtableContactDraft, belege: [BelegQuelle]) -> [ProvenanceHit] {
        var hits: [ProvenanceHit] = []
        if let email = draft.email {
            for adresse in emailAdressen(in: email) {
                if let source = quelleFuerEmail(adresse, belege) {
                    hits.append(ProvenanceHit(kind: .email, feld: "E-Mail", value: adresse, source: source))
                }
            }
        }
        if let telefon = draft.telefon, let source = quelleFuerTelefon(telefon, belege) {
            hits.append(ProvenanceHit(kind: .telefon, feld: "Telefon", value: telefon, source: source))
        }
        return hits
    }

    public static let belegtPrefix = "Belegt: "

    public static func provenanceLabel(_ hits: [ProvenanceHit]) -> String? {
        guard hits.isEmpty == false else { return nil }
        let teile = hits.map { "\($0.value) ← \($0.source)" }.joined(separator: ", ")
        return "\(belegtPrefix)\(teile)"
    }

    public static func warnLabel(_ verdict: Verdict) -> String {
        let values = verdict.ungrounded
            .map { "\($0.value) (\($0.feld))" }
            .joined(separator: ", ")
        return "Entwurf zurückgehalten — nicht belegte Angabe: \(values). Quelle nennen oder nachschlagen."
    }

    public static func modellHinweis(_ verdict: Verdict) -> String {
        let values = verdict.ungrounded
            .map { "\($0.kind.rawValue) „\($0.value)" + "\" (Feld \($0.feld))" }
            .joined(separator: "; ")
        return "\n\n[GROUNDING-GATE] Der Entwurf wurde NICHT als Karte angezeigt: folgende Werte sind "
            + "durch kein Tool-Ergebnis und keine Nutzer-Angabe belegt und dürfen nicht erfunden werden: "
            + "\(values). Nutze ein Lese-Werkzeug (z. B. search_contacts / lookup_kontakt / search_gmail) "
            + "für den echten Wert oder frag den Nutzer. Erfinde niemals eine Adresse oder Nummer."
    }

    static func istEmailBelegt(_ email: String, _ evidence: Evidence) -> Bool {
        let normalisiert = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalisiert.isEmpty == false else { return true }
        return evidence.kleingeschrieben.contains(normalisiert)
    }

    static func istTelefonBelegt(_ telefon: String, _ evidence: Evidence) -> Bool {
        let ziffern = telefon.filter { $0.isNumber }

        guard ziffern.count >= 5 else { return true }

        let nadel = String(ziffern.suffix(min(ziffern.count, 7)))
        return evidence.nurZiffern.contains(nadel)
    }

    static func emailAdressen(in text: String) -> [String] {
        let pattern = "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let area = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: area).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return String(text[r])
        }
    }
}
