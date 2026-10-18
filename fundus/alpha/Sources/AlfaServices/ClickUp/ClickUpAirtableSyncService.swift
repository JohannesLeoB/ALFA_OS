import Foundation
import AlfaKit

public enum ClickUpAirtableSyncError: Error, Sendable, Equatable, LocalizedError {
    case keinAnkerTask
    case feldFehltAufAnkerTask(String)
    case unbekanntesDropdownLabel(feld: String, label: String)

    public var errorDescription: String? {
        switch self {
        case .keinAnkerTask:
            return "Kein Anker-Task mit Custom Fields in dieser ClickUp-Liste gefunden."
        case .feldFehltAufAnkerTask(let feld):
            return "Custom Field „\(feld)“ existiert nicht (mehr) auf dem Anker-Task."
        case .unbekanntesDropdownLabel(let feld, let label):
            return "„\(label)“ ist keine bekannte Option von „\(feld)“ in ClickUp — kein Schreibversuch."
        }
    }
}

public struct ClickUpAirtableSyncPullErgebnis: Sendable, Equatable {
    public let uebernommeneFelder: [String]
    public let fehlerJeFeld: [String: String]

    public init(uebernommeneFelder: [String] = [], fehlerJeFeld: [String: String] = [:]) {
        self.uebernommeneFelder = uebernommeneFelder
        self.fehlerJeFeld = fehlerJeFeld
    }
}

public struct ClickUpAirtableSyncPruefungErgebnis: Sendable, Equatable {
    public let nochNieGesynct: [String]
    public let echteAenderung: [String]

    public init(nochNieGesynct: [String] = [], echteAenderung: [String] = []) {
        self.nochNieGesynct = nochNieGesynct
        self.echteAenderung = echteAenderung
    }

    public var isEmpty: Bool { nochNieGesynct.isEmpty && echteAenderung.isEmpty }
}

extension ClickUpAirtableFeldWert {
    static func ausClickUp(typ: ClickUpAirtableSyncFeld.Typ, ref: ClickUpCustomFieldRef) -> ClickUpAirtableFeldWert? {
        let dropdownOptionen: [(orderindex: Int, label: String)] = ref.options.compactMap { option in
            guard let orderindex = option.orderindex else { return nil }
            return (orderindex, option.name)
        }
        return ausClickUpRoh(typ: typ, rawValue: ref.rawValue, dropdownOptionen: dropdownOptionen)
    }
}

@MainActor
public struct ClickUpAirtableSyncService {
    public static let integrationID = "CLICKUP_AIRTABLE_FIELD_SYNC"

    private let clickUp: any ClickUpFetching
    private let clickUpActions: ClickUpTaskActionStore
    private let airtable: any AirtableRecordUpdating
    private let syncState: ClickUpAirtableSyncStateStore
    private let dataFlow: DataFlowLogger
    private let audit: AuditStore

    public init(
        clickUp: any ClickUpFetching = ClickUpClient(),
        clickUpActions: ClickUpTaskActionStore,
        airtable: any AirtableRecordUpdating = AirtableClient(),
        syncState: ClickUpAirtableSyncStateStore,
        dataFlow: DataFlowLogger,
        audit: AuditStore
    ) {
        self.clickUp = clickUp
        self.clickUpActions = clickUpActions
        self.airtable = airtable
        self.syncState = syncState
        self.dataFlow = dataFlow
        self.audit = audit
    }

    private struct Abweichung {
        let bruecke: ClickUpAirtableSyncFeld
        let value: ClickUpAirtableFeldWert
        let kanonisch: String
        let warNochNieGesynct: Bool
    }

    private func ermittleAbweichungen(
        listID: String, project: Project, vorabGeladeneTasks: [ClickUpTask]? = nil
    ) async throws -> [Abweichung] {
        let tasks: [ClickUpTask]
        if let vorabGeladeneTasks {
            tasks = vorabGeladeneTasks
        } else {
            tasks = try await clickUp.tasks(listID: listID)
        }
        guard let ankerTaskID = try ClickUpClient.ankerTask(in: tasks)?.id else {
            throw ClickUpAirtableSyncError.keinAnkerTask
        }
        let liveFields = try await clickUp.customFields(taskID: ankerTaskID)

        var abweichungen: [Abweichung] = []
        for bruecke in ClickUpAirtableSyncRegister.active {
            guard let liveField = try ClickUpCustomFieldRef.eindeutig(in: liveFields, name: bruecke.clickUpName) else { continue }
            guard let value = ClickUpAirtableFeldWert.ausClickUp(typ: bruecke.typ, ref: liveField) else { continue }
            let kanonisch = value.kanonischerVergleichswert
            let gespeicherterWert = syncState.letzterWert(projectNumber: project.projectNumber, feld: bruecke.clickUpName)
            guard gespeicherterWert != kanonisch else {
                continue
            }
            abweichungen.append(Abweichung(
                bruecke: bruecke, value: value, kanonisch: kanonisch, warNochNieGesynct: gespeicherterWert == nil))
        }
        return abweichungen
    }

    public func pruefeAenderungen(
        project: Project, vorabGeladeneTasks: [ClickUpTask]? = nil
    ) async throws -> ClickUpAirtableSyncPruefungErgebnis {
        guard let listID = project.links.clickUpListID, listID.isEmpty == false else {
            return ClickUpAirtableSyncPruefungErgebnis()
        }
        let abweichungen = try await ermittleAbweichungen(
            listID: listID, project: project, vorabGeladeneTasks: vorabGeladeneTasks)
        return ClickUpAirtableSyncPruefungErgebnis(
            nochNieGesynct: abweichungen.filter(\.warNochNieGesynct).map(\.bruecke.clickUpName),
            echteAenderung: abweichungen.filter { $0.warNochNieGesynct == false }.map(\.bruecke.clickUpName))
    }

    @discardableResult
    public func pull(project: Project, actorUserID: String) async throws -> ClickUpAirtableSyncPullErgebnis {
        guard let listID = project.links.clickUpListID, listID.isEmpty == false else {
            return ClickUpAirtableSyncPullErgebnis()
        }
        let abweichungen = try await ermittleAbweichungen(listID: listID, project: project)

        var uebernommen: [String] = []
        var fehlerJeFeld: [String: String] = [:]

        for abweichung in abweichungen {
            let bruecke = abweichung.bruecke
            let value = abweichung.value
            let kanonisch = abweichung.kanonisch
            guard let recordID = project.airtableRecordID else { continue }

            let airtableFelder: [String: AirtableFieldValue] = value.alsAirtableZahl.map { [bruecke.airtableName: .number($0)] }
                ?? [bruecke.airtableName: .string(value.alsAirtableText ?? "")]

            do {
                try await airtable.updateRecord(
                    baseID: AirtableRouting.projekte.baseID, table: AirtableRouting.projekte.tabelle,
                    recordID: recordID, fields: airtableFelder)
                try syncState.setzeLetztenWert(projectNumber: project.projectNumber, feld: bruecke.clickUpName, value: kanonisch)
                try? audit.append(AuditEntry(
                    actorUserID: actorUserID, projectID: project.projectNumber,
                    action: .airtableFeldAusClickUpUebernommen,
                    summary: "\(bruecke.clickUpName) → \(bruecke.airtableName) = \(kanonisch)", source: "clickup-pull"))
                uebernommen.append(bruecke.clickUpName)
                dataFlow.log(
                    integrationID: Self.integrationID, actorUserID: actorUserID, action: .success,
                    recordsWritten: 1,
                    summary: "Pull: \(bruecke.clickUpName) → \(bruecke.airtableName) = \(kanonisch) (Projekt \(project.projectNumber))")
            } catch {
                fehlerJeFeld[bruecke.clickUpName] = error.localizedDescription
                dataFlow.log(
                    integrationID: Self.integrationID, actorUserID: actorUserID, action: .error,
                    errorMessage: error.localizedDescription,
                    summary: "Pull fehlgeschlagen: \(bruecke.clickUpName) (Projekt \(project.projectNumber))")
            }
        }
        return ClickUpAirtableSyncPullErgebnis(uebernommeneFelder: uebernommen, fehlerJeFeld: fehlerJeFeld)
    }

    public func push(
        project: Project, feld: ClickUpAirtableSyncFeld, value: ClickUpAirtableFeldWert, actorUserID: String
    ) async throws {
        guard let listID = project.links.clickUpListID, listID.isEmpty == false else { return }
        let tasks = try await clickUp.tasks(listID: listID)
        guard let ankerTaskID = try ClickUpClient.ankerTask(in: tasks)?.id else {
            throw ClickUpAirtableSyncError.keinAnkerTask
        }
        let liveFields = try await clickUp.customFields(taskID: ankerTaskID)
        guard let liveField = try ClickUpCustomFieldRef.eindeutig(in: liveFields, name: feld.clickUpName) else {
            throw ClickUpAirtableSyncError.feldFehltAufAnkerTask(feld.clickUpName)
        }

        do {
            switch feld.typ {
            case .text, .zahl:
                let text = value.alsAirtableText ?? value.kanonischerVergleichswert
                try await clickUpActions.setCustomFieldValue(
                    taskID: ankerTaskID, listID: listID, fieldID: liveField.id, fieldName: feld.clickUpName,
                    value: text, projectID: project.projectNumber, actorUserID: actorUserID)
            case .date:
                guard case .date(let date) = value else {
                    throw ClickUpAirtableSyncError.feldFehltAufAnkerTask(feld.clickUpName)
                }
                try await clickUpActions.setCustomFieldDateValue(
                    taskID: ankerTaskID, listID: listID, fieldID: liveField.id, fieldName: feld.clickUpName,
                    value: date, projectID: project.projectNumber, actorUserID: actorUserID)
            case .dropdown:
                guard case .dropdown(let label) = value else {
                    throw ClickUpAirtableSyncError.feldFehltAufAnkerTask(feld.clickUpName)
                }
                guard let optionID = try liveField.optionIDStreng(forLabel: label) else {
                    throw ClickUpAirtableSyncError.unbekanntesDropdownLabel(feld: feld.clickUpName, label: label)
                }
                try await clickUpActions.setCustomFieldDropdownValue(
                    taskID: ankerTaskID, listID: listID, fieldID: liveField.id, fieldName: feld.clickUpName,
                    optionID: optionID, projectID: project.projectNumber, actorUserID: actorUserID)
            }
            try syncState.setzeLetztenWert(
                projectNumber: project.projectNumber, feld: feld.clickUpName, value: value.kanonischerVergleichswert)
            dataFlow.log(
                integrationID: Self.integrationID, actorUserID: actorUserID, action: .success,
                recordsWritten: 1,
                summary: "Push: \(feld.clickUpName) = \(value.kanonischerVergleichswert) (Projekt \(project.projectNumber))")
        } catch {
            dataFlow.log(
                integrationID: Self.integrationID, actorUserID: actorUserID, action: .error,
                errorMessage: error.localizedDescription,
                summary: "Push fehlgeschlagen: \(feld.clickUpName) (Projekt \(project.projectNumber))")
            throw error
        }
    }
}
