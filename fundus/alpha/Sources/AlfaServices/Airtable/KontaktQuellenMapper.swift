import Foundation
import AlfaKit

public enum KontaktQuellenMapper {
    private static func text(_ fields: [String: AirtableFieldValue], _ key: String) -> String? {
        let v = fields[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (v?.isEmpty == false) ? v : nil
    }

    private static func zahl(_ fields: [String: AirtableFieldValue], _ key: String) -> Int? {
        fields[key]?.numberValue.map { Int($0) }
    }

    static func adressTeile(_ fields: [String: AirtableFieldValue]) -> (strasse: String?, houseNumber: String?) {
        let roh = text(fields, "Straße")
        if let number = text(fields, "Hausnummer") { return (roh, number) }
        guard let roh else { return (nil, nil) }
        let geteilt = AdresseAufteilung.teile(roh)

        return (geteilt.strasse.isEmpty ? nil : geteilt.strasse, geteilt.houseNumber)
    }

    private static func adresse(_ fields: [String: AirtableFieldValue]) -> String? {
        let teile = adressTeile(fields)
        let strasseMitNr = [teile.strasse, teile.houseNumber]
            .compactMap { $0 }.joined(separator: " ")
        let plzOrt = [text(fields, "PLZ"), text(fields, "Ort")].compactMap { $0 }.joined(separator: " ")
        let rowItems = [strasseMitNr.isEmpty ? nil : strasseMitNr, plzOrt.isEmpty ? nil : plzOrt]
            .compactMap { $0 }
        return rowItems.isEmpty ? nil : rowItems.joined(separator: ", ")
    }

    private static func id(_ fields: [String: AirtableFieldValue], fallback: String) -> String {
        fields["_airtableRecordID"]?.stringValue ?? fallback
    }

    public static func mappeKundenGolden(_ records: [[String: AirtableFieldValue]]) -> [StudioContact] {
        records.compactMap { f in
            guard let name = text(f, "Firma / Name") else { return nil }
            return StudioContact(
                id: id(f, fallback: name), name: name,
                organisation: text(f, "Firma / Name"),
                email: text(f, "E-Mail"), telefon: text(f, "Telefon"),

                adresse: adresse(f),

                strasse: adressTeile(f).strasse, houseNumber: adressTeile(f).houseNumber,
                plz: text(f, "PLZ"), ort: text(f, "Ort"),

                land: text(f, "Land"), sevDeskKontaktID: text(f, "sevDesk-Contact-ID"),
                zahlungszielTage: zahl(f, "Zahlungsziel (Tage)"),
                zahlungsbedingungText: text(f, "Zahlungsbedingung (Text)"),
                projekt: text(f, "Projekt (Nummer)") ?? text(f, "Projekt (MM-Kontakte)"),
                kategorie: "Kunde",
                vorname: text(f, "Vorname"), nachname: text(f, "Nachname"),

                customerNumber: text(f, "Kundennummer"),
                history: text(f, GoldenAppendOnly.historyField), source: .golden)
        }
    }

    public static func mappeLieferanten(_ records: [[String: AirtableFieldValue]]) -> [StudioContact] {
        records.compactMap { f in
            guard let name = text(f, "Firma / Name") else { return nil }
            return StudioContact(
                id: id(f, fallback: name), name: name,
                organisation: text(f, "Firma / Name"),
                email: text(f, "E-Mail"), telefon: text(f, "Telefon"),
                adresse: adresse(f),
                strasse: adressTeile(f).strasse, houseNumber: adressTeile(f).houseNumber,
                plz: text(f, "PLZ"), ort: text(f, "Ort"),
                kategorie: "Lieferant", source: .lieferant)
        }
    }

    public static func mappeWeitereKontakte(_ records: [[String: AirtableFieldValue]]) -> [StudioContact] {
        records.compactMap { f in
            guard let name = text(f, "Firma / Name") else { return nil }
            return StudioContact(
                id: id(f, fallback: name), name: name,
                organisation: text(f, "Organisation"),
                email: text(f, "E-Mail"), telefon: text(f, "Telefon"),
                kategorie: text(f, "Kategorie"),
                vorname: text(f, "Vorname"), nachname: text(f, "Nachname"),
                photoURL: f["Foto"]?.firstAttachmentURL, source: .weitereKontakte)
        }
    }

    public static func vereinigeAlle(
        kundenGolden: [[String: AirtableFieldValue]],
        lieferanten: [[String: AirtableFieldValue]],
        weitereKontakte: [[String: AirtableFieldValue]]
    ) -> [StudioContact] {
        let alle = mappeKundenGolden(kundenGolden)
            + mappeLieferanten(lieferanten)
            + mappeWeitereKontakte(weitereKontakte)
        return KontaktMerge.vereinige(airtable: alle, lokal: [])
    }
}
