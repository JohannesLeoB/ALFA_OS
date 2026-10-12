import Foundation
import Observation
import MykilosKit

@MainActor
@Observable
public final class ProjektArchivStatusWriter {
    public private(set) var saveState: SaveState = .idle

    private let clickUp: (ClickUpListWriting)?
    private let airtable: AirtableRecordUpdating?
    private let audit: AuditStore
    private let airtableBaseID: String
    private let airtableTable: String

    public init(
        clickUp: (ClickUpListWriting)? = ClickUpClient(),
        airtable: AirtableRecordUpdating?,
        audit: AuditStore,

        airtableBaseID: String = AirtableRouting.projekte.baseID,
        airtableTable: String = AirtableRouting.projekte.tabelle
    ) {
        self.clickUp = clickUp
        self.airtable = airtable
        self.audit = audit
        self.airtableBaseID = airtableBaseID
        self.airtableTable = airtableTable
    }

    public func archiviere(
        clickUpListID: String?, aktuellerListenName: String?,
        airtableRecordID: String?, projektID: String, actorUserID: String
    ) async throws {
        try await schreibe(
            clickUpListID: clickUpListID, aktuellerListenName: aktuellerListenName,
            listenTransform: ProjektArchivMarker.markiere,
            airtableRecordID: airtableRecordID, phase: "Archiviert",
            projektID: projektID, actorUserID: actorUserID,
            action: .projektArchiviert, summary: "Projekt archiviert (ClickUp-Marker + Airtable-Phase)")
    }

    public func reaktiviere(
        clickUpListID: String?, aktuellerListenName: String?,
        airtableRecordID: String?, projektID: String, actorUserID: String
    ) async throws {
        try await schreibe(
            clickUpListID: clickUpListID, aktuellerListenName: aktuellerListenName,
            listenTransform: ProjektArchivMarker.entmarkiere,
            airtableRecordID: airtableRecordID, phase: "Aktiv",
            projektID: projektID, actorUserID: actorUserID,
            action: .projektReaktiviert, summary: "Projekt reaktiviert (Marker entfernt + Airtable-Phase)")
    }

    private func schreibe(
        clickUpListID: String?, aktuellerListenName: String?,
        listenTransform: (String) -> String,
        airtableRecordID: String?, phase: String,
        projektID: String, actorUserID: String,
        action: AuditEntry.Action, summary: String
    ) async throws {
        saveState = .saving
        do {
            if let listID = clickUpListID, let name = aktuellerListenName, let clickUp {
                let neu = listenTransform(name)
                if neu != name {
                    try await clickUp.renameList(listID: listID, name: neu)
                }
            }

            if let recordID = airtableRecordID, let airtable {
                try await airtable.updateRecord(
                    baseID: airtableBaseID, table: airtableTable, recordID: recordID,
                    fields: ["Phase": .string(phase)])
            }
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projektID,
                action: action, summary: summary, source: "archiv"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}
