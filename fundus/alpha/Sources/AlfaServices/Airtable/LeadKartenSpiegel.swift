import Foundation
import AlfaKit

public enum LeadKartenAirtableSync {
    static let spiegel = AirtableTwoWaySync(tabelleID: CompanySetup.valueOrEmpty("airtable.table.lead_cards"), primaerFeld: "Projektnummer")

    public static func synchronisiere(store: LeadKartenStore) async {
        if let rowItems = try? await spiegel.alleZeilen() {
            let lokal = (try? await store.alleKarten()) ?? []
            let lokalMap = Dictionary(uniqueKeysWithValues: lokal.map { ($0.projectNumber, $0.aktualisiertAm) })
            for rowItem in rowItems {
                switch LastWriteWinsMerge.entscheide(remote: rowItem, lokalAktualisiertAm: lokalMap[rowItem.key]) {
                case .importieren, .uebernehmen:
                    guard let taskID = rowItem.felder["Task-ID"], taskID.isEmpty == false else { continue }
                    try? await store.importiere(LeadKarteRecord(
                        projectNumber: rowItem.key, taskID: taskID,
                        status: rowItem.felder["Status"] ?? LeadKartenStore.statusOffen,
                        aktualisiertAm: rowItem.aktualisiertAm))
                case .lokalLoeschen, .behalten:
                    continue
                }
            }
        }
        for card in (try? await store.alleKarten()) ?? [] {
            await pushe(card)
        }
    }

    public static func pushe(_ card: LeadKarteRecord) async {
        try? await spiegel.upsert(AirtableSyncRow(
            key: card.projectNumber,
            aktualisiertAm: card.aktualisiertAm,
            geloeschtLokal: false,
            felder: ["Task-ID": card.taskID, "Status": card.status]))
    }
}
