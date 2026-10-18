import Foundation

public enum KontaktMerge {
    public static func schluesselEmail(_ email: String?) -> String? {
        guard let e = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !e.isEmpty else { return nil }
        return e
    }

    public static func schluesselTelefon(_ telefon: String?) -> String? {
        guard let t = telefon else { return nil }
        let ziffern = t.filter(\.isNumber)
        guard ziffern.count >= 6 else { return nil }
        return String(ziffern.suffix(9))
    }

    static func key(_ k: StudioContact) -> [String] {
        var out: [String] = []
        if let e = schluesselEmail(k.email) { out.append("mail:" + e) }
        if let t = schluesselTelefon(k.telefon) { out.append("tel:" + t) }
        return out
    }

    public static func vereinige(airtable: [StudioContact], lokal: [StudioContact]) -> [StudioContact] {
        var result: [StudioContact] = []
        var index: [String: Int] = [:]

        func aufnehmenOderHeilen(_ k: StudioContact) {
            let keys = key(k)

            if let pos = keys.compactMap({ index[$0] }).first {
                result[pos] = heile(kanonisch: result[pos], mit: k)

                for key in key(result[pos]) where index[key] == nil { index[key] = pos }
                return
            }
            result.append(k)
            let pos = result.count - 1
            for key in keys where index[key] == nil { index[key] = pos }
        }

        airtable.forEach(aufnehmenOderHeilen)
        lokal.forEach(aufnehmenOderHeilen)
        return result
    }

    static func heile(kanonisch: StudioContact, mit anderer: StudioContact) -> StudioContact {
        var k = kanonisch
        if k.organisation.isEmpty { k.organisation = anderer.organisation }
        if k.email.isEmpty { k.email = anderer.email }
        if k.telefon.isEmpty { k.telefon = anderer.telefon }
        if k.adresse.isEmpty { k.adresse = anderer.adresse }
        if k.projekt.isEmpty { k.projekt = anderer.projekt }
        if k.kategorie.isEmpty { k.kategorie = anderer.kategorie }
        if k.vorname.isEmpty { k.vorname = anderer.vorname }
        if k.nachname.isEmpty { k.nachname = anderer.nachname }
        if k.photoURL.isEmpty { k.photoURL = anderer.photoURL }
        return k
    }

    public static func wendeUeberschreibungenAn(
        basis: [StudioContact], ueberschreibungen: [StudioContact]) -> [StudioContact] {
        guard !ueberschreibungen.isEmpty else { return basis }
        let map = Dictionary(ueberschreibungen.map { ($0.id, $0) }, uniquingKeysWith: { _, neu in neu })
        return basis.map { k in
            guard let ue = map[k.id] else { return k }
            return ueberschreibe(basis: k, mit: ue)
        }
    }

    static func ueberschreibe(basis: StudioContact, mit ue: StudioContact) -> StudioContact {
        var k = basis
        let neuerName = ue.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !neuerName.isEmpty { k.name = ue.name }
        if !ue.organisation.isEmpty { k.organisation = ue.organisation }
        if !ue.email.isEmpty { k.email = ue.email }
        if !ue.telefon.isEmpty { k.telefon = ue.telefon }
        if !ue.adresse.isEmpty { k.adresse = ue.adresse }
        if !ue.projekt.isEmpty { k.projekt = ue.projekt }
        if !ue.kategorie.isEmpty { k.kategorie = ue.kategorie }
        if !ue.vorname.isEmpty { k.vorname = ue.vorname }
        if !ue.nachname.isEmpty { k.nachname = ue.nachname }
        if !ue.photoURL.isEmpty { k.photoURL = ue.photoURL }
        return k
    }

    public static func findeDubletten(kandidat: StudioContact, stock: [StudioContact]) -> [StudioContact] {
        let keys = Set(key(kandidat))
        guard !keys.isEmpty else { return [] }
        return stock.filter { !Set(key($0)).isDisjoint(with: keys) }
    }
}

private extension Optional where Wrapped == String {
    var isEmpty: Bool {
        switch self {
        case .none: return true
        case .some(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
