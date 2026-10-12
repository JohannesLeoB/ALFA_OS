import Foundation
import MykilosKit

public enum SevdeskBelegRegisterAirtableSync {
    static let spiegel = AirtableTwoWaySync(tabelleID: CompanySetup.valueOrEmpty("airtable.table.document_register"),
                                     primaerFeld: "sevDesk-Order-ID")
    static let encoder: JSONEncoder = {
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
        enc.dateEncodingStrategy = .iso8601; return enc
    }()
    static let decoder: JSONDecoder = {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601; return dec
    }()

    public static func synchronisiere(register: SevdeskBelegRegisterSpeicher = .init()) async {
        if let rowItems = try? await spiegel.alleZeilen() {
            for rowItem in rowItems {
                guard let json = rowItem.felder["JSON"],
                      let entry = try? decoder.decode(SevdeskBelegEintrag.self, from: Data(json.utf8))
                else { continue }
                try? register.uebernimm(entry)
            }
        }
        for entry in register.alle() {
            await pushe(entry)
        }
    }

    public static func pushe(_ entry: SevdeskBelegEintrag) async {
        guard let json = String(data: (try? encoder.encode(entry)) ?? Data(), encoding: .utf8),
              json.isEmpty == false else { return }
        try? await spiegel.upsert(AirtableSyncRow(
            key: entry.sevdeskOrderID,
            aktualisiertAm: Date().timeIntervalSince1970,
            geloeschtLokal: false,
            felder: ["Projektnummer": entry.projectNumber,
                     "Belegart": entry.belegArt,
                     "Belegnummer": entry.belegnummer,
                     "JSON": json]))
    }
}
