import Foundation
import MykilosKit

public struct AirtableSyncRow: Sendable, Equatable {
    public let key: String
    public let aktualisiertAm: Double
    public let geloeschtLokal: Bool

    public let felder: [String: String]

    public init(key: String, aktualisiertAm: Double, geloeschtLokal: Bool,
                felder: [String: String]) {
        self.key = key
        self.aktualisiertAm = aktualisiertAm
        self.geloeschtLokal = geloeschtLokal
        self.felder = felder
    }
}

public enum LastWriteWinsMerge {
    public enum Entscheidung: Equatable, Sendable {
        case importieren
        case uebernehmen
        case behalten
        case lokalLoeschen
    }

    public static func entscheide(remote: AirtableSyncRow,
                                  lokalAktualisiertAm: Double?) -> Entscheidung {
        if remote.geloeschtLokal { return lokalAktualisiertAm == nil ? .behalten : .lokalLoeschen }
        guard let lokal = lokalAktualisiertAm else { return .importieren }

        return remote.aktualisiertAm > lokal + 0.001 ? .uebernehmen : .behalten
    }
}

public struct AirtableTwoWaySync: Sendable {
    public static let hubBaseID = AirtableClient.projektHubBaseID

    public let tabelleID: String

    public let primaerFeld: String

    public init(tabelleID: String, primaerFeld: String) {
        self.tabelleID = tabelleID
        self.primaerFeld = primaerFeld
    }

    public func upsert(_ rowItem: AirtableSyncRow, client: AirtableClient = AirtableClient()) async throws {
        var felder: [String: AirtableFieldValue] = [
            primaerFeld: .string(rowItem.key),
            "Aktualisiert am": .number(rowItem.aktualisiertAm)
        ]
        if rowItem.geloeschtLokal { felder["Geloescht lokal"] = .bool(true) }
        for (name, value) in rowItem.felder { felder[name] = .string(value) }

        if let vorhandene = try await recordID(fuer: rowItem.key, client: client) {
            try await client.updateRecord(baseID: Self.hubBaseID, table: tabelleID,
                                          recordID: vorhandene, fields: felder)
        } else {
            _ = try await client.createRecords(baseID: Self.hubBaseID, table: tabelleID,
                                               recordsFields: [felder])
        }
    }

    public func alleZeilen(client: AirtableClient = AirtableClient()) async throws -> [AirtableSyncRow] {
        let rows = try await client.fetchRecords(baseID: Self.hubBaseID, table: tabelleID)
        return rows.compactMap { row in
            guard let key = row[primaerFeld]?.stringValue, key.isEmpty == false
            else { return nil }
            var felder: [String: String] = [:]
            for (name, value) in row where name != primaerFeld {
                if let text = value.stringValue { felder[name] = text }
            }
            return AirtableSyncRow(
                key: key,
                aktualisiertAm: row["Aktualisiert am"]?.numberValue ?? 0,
                geloeschtLokal: row["Geloescht lokal"]?.boolValue ?? false,
                felder: felder)
        }
    }

    private func recordID(fuer key: String, client: AirtableClient) async throws -> String? {
        try await client.fetchRecordIDs(baseID: Self.hubBaseID, table: tabelleID,
                                        wherePrimaryField: primaerFeld, equals: key).first
    }
}
