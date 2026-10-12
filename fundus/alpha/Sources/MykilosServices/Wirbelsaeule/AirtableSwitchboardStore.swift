import Foundation
import MykilosKit

public struct AirtableSwitchboardStore: Sendable {
    public static let schemaVersion = 1

    private let airtableCreate: any AirtableRecordCreating
    private let airtableFetch: any AirtableFetching
    private let baseID: String
    private let packageTable: String
    private let positionTable: String

    public init(
        airtableCreate: any AirtableRecordCreating,
        airtableFetch: any AirtableFetching,
        baseID: String = AirtableClient.writableBaseID,
        packageTable: String = "Commercial Packages",
        positionTable: String = "Commercial Positions"
    ) {
        self.airtableCreate = airtableCreate
        self.airtableFetch = airtableFetch
        self.baseID = baseID
        self.packageTable = packageTable
        self.positionTable = positionTable
    }

    @discardableResult
    public func schreibeRevision(_ package: CommercialDraftPackage) async throws -> AirtableSwitchboardWriteResult {
        let packageRecordID: String
        let warNeu: Bool
        if let vorhandeneID = try await bestehendesPaket(payloadSHA256: package.payloadSHA256) {
            packageRecordID = vorhandeneID
            warNeu = false
        } else {
            packageRecordID = try await airtableCreate.createRecord(
                baseID: baseID, table: packageTable, fields: Self.paketFelder(package))
            warNeu = true
        }

        let vorhandeneSequenzen = warNeu ? [] : try await vorhandeneSequenzen(packageRecordID: packageRecordID)
        var geschrieben = 0
        for position in package.positionen {
            guard vorhandeneSequenzen.contains(position.sequenz) == false else { continue }
            _ = try await airtableCreate.createRecord(
                baseID: baseID, table: positionTable,
                fields: Self.positionsFelder(position, packageRecordID: packageRecordID))
            geschrieben += 1
        }

        return AirtableSwitchboardWriteResult(
            packageRecordID: packageRecordID, positionenGeschrieben: geschrieben,
            warBereitsVollstaendig: warNeu == false && geschrieben == 0)
    }

    private func bestehendesPaket(payloadSHA256: String) async throws -> String? {
        let records = try await airtableFetch.fetchRecords(baseID: baseID, table: packageTable)
        for record in records where record["Payload-Hash"]?.stringValue == payloadSHA256 {
            return record["_airtableRecordID"]?.stringValue
        }
        return nil
    }

    private func vorhandeneSequenzen(packageRecordID: String) async throws -> Set<Int> {
        let records = try await airtableFetch.fetchRecords(baseID: baseID, table: positionTable)
        var sequenzen: Set<Int> = []
        for record in records {
            guard case .array(let verlinktePakete)? = record["Paket"], verlinktePakete.contains(packageRecordID) else { continue }
            if let seq = record["Sequenz"]?.anyStringValue.flatMap(Int.init) { sequenzen.insert(seq) }
        }
        return sequenzen
    }

    static func paketFelder(_ package: CommercialDraftPackage) -> [String: AirtableFieldValue] {
        var felder: [String: AirtableFieldValue] = [
            "Package-ID": .string(package.packageID.uuidString),
            "Revision": .number(Double(package.revision)),
            "Payload-Hash": .string(package.payloadSHA256),
            "Schema-Version": .number(Double(package.payloadSchemaVersion)),
            "Projekt-ID": .string(package.projektID),
            "Projekt-Code": .string(package.projektCode),
            "Kontakt-ID": .string(package.contactID),
            "Prozessart": .string(package.processType.rawValue),
            "Titel": .string(package.title),
            "Waehrung": .string(package.currency),
            "Steuerkontext": .string(package.steuerKontextID),
            "Erwartetes-Netto": .string(package.expectedNet.description),
            "Uebergabe-Status": .string(package.übergabeStatus.rawValue),
            "Erstellt-von": .string(package.createdByUserID),
            "Erstellt-am": .string(ISO8601DateFormatter().string(from: package.createdAt))
        ]
        if let einleitungsText = package.einleitungsText, einleitungsText.isEmpty == false {
            felder["Einleitungstext"] = .string(einleitungsText)
        }
        if let schlussText = package.schlussText, schlussText.isEmpty == false {
            felder["Schlusstext"] = .string(schlussText)
        }
        if let sevdeskOrderID = package.sevdeskOrderID {
            felder["Sevdesk-Order-ID"] = .string(sevdeskOrderID)
        }
        return felder
    }

    static func positionsFelder(_ position: CommercialDraftPosition, packageRecordID: String) -> [String: AirtableFieldValue] {
        var felder: [String: AirtableFieldValue] = [
            "Position-ID": .string(position.positionID.uuidString),
            "Paket": .array([packageRecordID]),
            "Sequenz": .number(Double(position.sequenz)),
            "Art": .string(position.kind.rawValue),
            "Bezeichnung": .string(position.label),
            "Menge": .string(position.quantity.description),
            "Einheit": .string(position.einheitText),
            "Steuerkontext": .string(position.steuerKontextID),
            "Mapping-Status": .string(position.mappingState.rawValue),
            "Positions-Hash": .string(position.positionSHA256)
        ]

        if let vk = position.vkNettoEinzel {
            felder["Verkaufspreis-Netto"] = .string(vk.description)
        }
        if let mykilosArtikelID = position.mykilosArtikelID {
            felder["MykilOS-Artikel-ID"] = .string(mykilosArtikelID)
        }
        if let beschreibung = position.beschreibung, beschreibung.isEmpty == false {
            felder["Beschreibung"] = .string(beschreibung)
        }
        return felder
    }
}

public struct AirtableSwitchboardWriteResult: Equatable, Sendable {
    public let packageRecordID: String
    public let positionenGeschrieben: Int

    public let warBereitsVollstaendig: Bool
}
