import Foundation
import GRDB
import AlfaKit

public actor VolltextSucheStore {
    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func suche(_ roh: String, grenze: Int = 40) throws -> [VolltextTreffer] {
        let q = roh.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return [] }
        let like = "%\(q)%"

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        func dekodiere<T: Decodable>(_ typ: T.Type, _ json: String?) -> T? {
            guard let json else { return nil }
            return try? dec.decode(T.self, from: Data(json.utf8))
        }

        return try db.read { conn in
            var treffer: [VolltextTreffer] = []

            for row in try Row.fetchAll(conn, sql:
                "SELECT json FROM bemusterungen WHERE lower(json) LIKE ?", arguments: [like]) {
                guard let m = dekodiere(BemusterungsMuster.self, row["json"]) else { continue }
                let felder: [String?] = [m.label, m.hersteller, m.kategorie, m.articleNumber, m.notiz, m.draftName]
                guard let s = Self.schnipsel(felder, q) else { continue }
                treffer.append(VolltextTreffer(id: "bem-\(m.id)", projectNumber: m.projectNumber,
                                               area: .sampling, title: m.label, schnipsel: s))
            }

            for row in try Row.fetchAll(conn, sql:
                "SELECT json FROM servicefaelle WHERE lower(json) LIKE ?", arguments: [like]) {
                guard let f = dekodiere(ServiceFall.self, row["json"]) else { continue }
                let felder: [String?] = [f.title, f.beschreibung, f.melder, f.art.label]
                guard let s = Self.schnipsel(felder, q) else { continue }
                treffer.append(VolltextTreffer(id: "svc-\(f.id)", projectNumber: f.projectNumber,
                                               area: .service, title: f.title, schnipsel: s))
            }

            for row in try Row.fetchAll(conn, sql:
                "SELECT json FROM meilensteine WHERE lower(json) LIKE ?", arguments: [like]) {
                guard let m = dekodiere(Meilenstein.self, row["json"]) else { continue }
                let felder: [String?] = [m.title, m.notiz]
                guard let s = Self.schnipsel(felder, q) else { continue }
                treffer.append(VolltextTreffer(id: "ms-\(m.id)", projectNumber: m.projectNumber,
                                               area: .termine, title: m.title, schnipsel: s))
            }

            for row in try Row.fetchAll(conn, sql:
                "SELECT json FROM telefonnotizen WHERE lower(json) LIKE ?", arguments: [like]) {
                guard let n = dekodiere(Telefonnotiz.self, row["json"]) else { continue }
                let felder: [String?] = [n.kontakt, n.content, n.folgeAufgabe]
                guard let s = Self.schnipsel(felder, q) else { continue }
                let title = n.kontakt.isEmpty ? "Telefonnotiz" : "Telefonat · \(n.kontakt)"
                treffer.append(VolltextTreffer(id: "tel-\(n.id)", projectNumber: n.projectNumber,
                                               area: .telefonnotiz, title: title, schnipsel: s))
            }

            return Array(treffer.prefix(grenze))
        }
    }

    static func schnipsel(_ felder: [String?], _ q: String) -> String? {
        for fall in felder {
            guard let text = fall, text.isEmpty == false,
                  let area = text.range(of: q, options: .caseInsensitive) else { continue }
            let start = text.index(area.lowerBound,
                                   offsetBy: -24, limitedBy: text.startIndex) ?? text.startIndex
            let ende = text.index(area.upperBound,
                                  offsetBy: 40, limitedBy: text.endIndex) ?? text.endIndex
            var s = String(text[start..<ende])
            if start > text.startIndex { s = "…" + s }
            if ende < text.endIndex { s += "…" }
            return s.replacingOccurrences(of: "\n", with: " ")
        }
        return nil
    }
}
