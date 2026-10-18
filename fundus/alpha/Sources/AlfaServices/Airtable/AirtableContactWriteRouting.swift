import Foundation
import AlfaKit

public enum AirtableContactWriteRouting {
    public static func target(fuer draft: AirtableContactDraft) -> (baseID: String, table: String, fields: [String: AirtableFieldValue]) {
        if draft.intent == .update, draft.source == .golden {
            return (GoldenKundeAirtableWriter.baseID, GoldenKundeAirtableWriter.tableID,
                    goldenFelder(draft))
        }
        let input = WeitereKontaktEingabe(
            name: draft.name, organisation: draft.organisation, email: draft.email,
            telefon: draft.telefon, adresse: draft.adresse, kategorie: draft.kategorie,
            projektnummer: draft.projekt)
        return (WeitereKontaktAirtableWriter.baseID, WeitereKontaktAirtableWriter.tableID,
                WeitereKontaktMapper.felder(input))
    }

    static func goldenFelder(_ draft: AirtableContactDraft) -> [String: AirtableFieldValue] {
        var f: [String: AirtableFieldValue] = [:]
        if let projekt = draft.projekt { f["Projekt (Nummer)"] = .string(projekt) }
        if let history = draft.history { f[GoldenAppendOnly.historyField] = .string(history) }
        guard draft.vollerFeldsatz else { return f }

        f[GoldenKundeMapper.feldFirmaName] = .string(draft.name)
        if let v = draft.email { f[GoldenKundeMapper.feldEmail] = .string(v) }
        if let v = draft.telefon { f[GoldenKundeMapper.feldTelefon] = .string(v) }
        if let v = draft.strasse { f[GoldenKundeMapper.feldStrasse] = .string(v) }
        if let v = draft.houseNumber { f[GoldenKundeMapper.feldHausnummer] = .string(v) }
        if let v = draft.plz { f[GoldenKundeMapper.feldPLZ] = .string(v) }
        if let v = draft.ort { f[GoldenKundeMapper.feldOrt] = .string(v) }
        if let v = draft.land { f["Land"] = .string(v) }
        return f
    }
}
