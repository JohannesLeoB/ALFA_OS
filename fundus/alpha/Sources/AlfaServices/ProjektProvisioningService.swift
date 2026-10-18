import Foundation
import Observation
import AlfaKit

public protocol DriveFolderProvisioning: Sendable {
    func findOrCreateSubfolder(parentID: String, name: String) async throws -> String
}

extension GoogleDriveClient: DriveFolderProvisioning {}

@MainActor
@Observable
public final class ProjektProvisioningService {
    public private(set) var saveState: SaveState = .idle

    private let drive: any DriveFolderProvisioning
    private let airtableCreate: any AirtableRecordCreating
    private let airtableFetch: any AirtableFetching
    private let ledger: ProvisioningLedger
    private let audit: AuditStore
    private let writeShadow: WriteShadowRecorder

    private let isWritable: (String, String) -> Bool

    private let clickUp: (any ClickUpFetching & ClickUpProjectProvisioning)?

    public init(
        drive: any DriveFolderProvisioning,
        airtableCreate: any AirtableRecordCreating,
        airtableFetch: any AirtableFetching,
        ledger: ProvisioningLedger,
        audit: AuditStore,
        writeShadow: WriteShadowRecorder,
        isWritable: @escaping (String, String) -> Bool = AirtableClient.isWritable,
        clickUp: (any ClickUpFetching & ClickUpProjectProvisioning)? = nil
    ) {
        self.drive = drive
        self.airtableCreate = airtableCreate
        self.airtableFetch = airtableFetch
        self.ledger = ledger
        self.audit = audit
        self.writeShadow = writeShadow
        self.isWritable = isWritable
        self.clickUp = clickUp
    }

    @discardableResult
    public func provision(
        plan: ProvisioningPlan,
        mode: ProvisioningMode,
        driveParentID: String,
        airtableBaseID: String,
        airtableTabelle: String,
        clickUpFolderID: String? = nil,
        actorUserID: String
    ) async throws -> ProvisioningResult {
        guard mode == .test else { throw ProvisioningError.writeGateGesperrt }

        saveState = .saving
        var result = (try ledger.entry(fuer: plan.idempotenzSchluessel))
            ?? ProvisioningResult(idempotenzSchluessel: plan.idempotenzSchluessel,
                                  projektnummer: plan.projektnummer.appFormat, kdnr: plan.kdnr)

        do {
            if result.hat(.driveOrdnerbaum) == false {
                result = try await provisioniereDrive(plan: plan, driveParentID: driveParentID, into: result)
                result.erledigteSchritte.insert(.driveOrdnerbaum)
                result.status = .teilweise
                try ledger.speichere(result)
            }

            if result.hat(.airtableRecord) == false {
                result = try await provisioniereAirtable(
                    plan: plan, baseID: airtableBaseID, tabelle: airtableTabelle, mode: mode,
                    actorUserID: actorUserID, into: result)
                result.erledigteSchritte.insert(.airtableRecord)
                try ledger.speichere(result)
            }

            if let clickUp, let clickUpFolderID, result.hat(.clickUpStruktur) == false {
                result = try await provisioniereClickUp(
                    plan: plan, folderID: clickUpFolderID, client: clickUp, into: result)
                result.erledigteSchritte.insert(.clickUpStruktur)
                try ledger.speichere(result)
            }

            result.status = .vollstaendig
            result.lastError = nil
            try ledger.speichere(result)
        } catch {
            result.status = .error
            result.lastError = String(describing: error)
            try? ledger.speichere(result)
            saveState = .failed(result.lastError ?? "Fehler")
            throw error
        }

        do {
            let clickUpTeil = result.clickUpListID.map { " · ClickUp \($0)" } ?? ""
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: plan.projektnummer.appFormat,
                action: .projectLinked,
                summary: "Projekt-Geburt (TEST-Sandbox): \(plan.folderName) · Drive \(result.driveProjectFolderId ?? "?") · Airtable \(result.airtableRecordID ?? "?")\(clickUpTeil)"))
        } catch {
            MykLog.lifecycle.error("Provisioning-Audit fehlgeschlagen: \(String(describing: error), privacy: .public)")
        }
        saveState = .saved(Date())
        return result
    }

    private func provisioniereDrive(plan: ProvisioningPlan, driveParentID: String, into start: ProvisioningResult) async throws -> ProvisioningResult {
        var result = start
        do {
            let testFolderID = try await drive.findOrCreateSubfolder(parentID: driveParentID, name: "_TEST_PROVISIONING")
            let gebaut = try await DriveOrdnerbaumBuilder.baue(
                drive: drive, parentID: testFolderID, folderName: plan.folderName,
                schema: plan.schema, bestehendeUnterordnerIDs: result.driveUnterordnerIDs,
                bekannteRootOrdnerID: result.driveProjectFolderId)
            result.driveProjectFolderId = gebaut.rootOrdnerID
            result.driveUnterordnerIDs = gebaut.unterordnerIDs
            return result
        } catch {
            throw ProvisioningError.schrittFehlgeschlagen(.driveOrdnerbaum, String(describing: error))
        }
    }

    private func provisioniereAirtable(plan: ProvisioningPlan, baseID: String, tabelle: String, mode: ProvisioningMode, actorUserID: String, into start: ProvisioningResult) async throws -> ProvisioningResult {
        var result = start

        guard isWritable(baseID, tabelle) else {
            throw ProvisioningError.schrittFehlgeschlagen(
                .airtableRecord,
                "Tabelle \(tabelle)@\(baseID) ist nicht auf AirtableClient.writableMap — bitte zuerst von der Administration auf die Schreib-Whitelist setzen lassen.")
        }

        if let bestehendeID = try? await findeBestehendenRecord(plan: plan, baseID: baseID, tabelle: tabelle) {
            result.airtableRecordID = bestehendeID
            return result
        }

        var felder: [String: AirtableFieldValue] = plan.airtableFelder
            .reduce(into: [:]) { $0[$1.key] = .string($1.value) }

        if let name = plan.airtableFelder["Projektname"] {
            felder["Projektname"] = .string(name.hasPrefix(TestMarker.namePrefix) ? name : TestMarker.namePrefix + name)
        }
        felder["Quelle"] = .string(TestMarker.quelleFieldValue)
        felder["Projektnummer"] = .string(plan.projektnummer.appFormat)

        do {
            let recordID = try await airtableCreate.createRecord(baseID: baseID, table: tabelle, fields: felder)
            result.airtableRecordID = recordID

            try? writeShadow.recordAirtableWrite(
                action: .create, actorUserID: actorUserID, baseID: baseID, table: tabelle,
                recordID: recordID, fields: felder, mode: mode, result: .ok)
            return result
        } catch {
            try? writeShadow.recordAirtableWrite(
                action: .create, actorUserID: actorUserID, baseID: baseID, table: tabelle,
                recordID: nil, fields: felder, mode: mode, result: .error, errorMessage: String(describing: error))
            throw ProvisioningError.schrittFehlgeschlagen(.airtableRecord, String(describing: error))
        }
    }

    private func provisioniereClickUp(
        plan: ProvisioningPlan, folderID: String,
        client: any ClickUpFetching & ClickUpProjectProvisioning, into start: ProvisioningResult
    ) async throws -> ProvisioningResult {
        var result = start
        let listsName = TestMarker.namePrefix + plan.folderName
        do {
            let listID = try await client.findOrCreateList(folderID: folderID, name: listsName, content: nil)
            result.clickUpListID = listID

            let bestehende = Set((try? await client.tasks(listID: listID))?.map(\.name) ?? [])
            for taskName in ClickUpProjectTemplate.standardKundenprojekt where bestehende.contains(taskName) == false {
                _ = try await client.createTask(listID: listID, name: taskName)
            }
            return result
        } catch {
            throw ProvisioningError.schrittFehlgeschlagen(.clickUpStruktur, String(describing: error))
        }
    }

    private func findeBestehendenRecord(plan: ProvisioningPlan, baseID: String, tabelle: String) async throws -> String? {
        let records = try await airtableFetch.fetchRecords(baseID: baseID, table: tabelle)
        let match = records.first { fields in
            fields["Projektnummer"]?.stringValue == plan.projektnummer.appFormat
                && fields["Quelle"]?.stringValue == TestMarker.quelleFieldValue
        }
        return match?["_airtableRecordID"]?.stringValue
    }
}
