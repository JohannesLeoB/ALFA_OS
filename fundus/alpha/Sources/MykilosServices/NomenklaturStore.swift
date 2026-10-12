import Foundation
import Observation
import GRDB
import MykilosKit

private struct OrdnerKonnektorRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "ordnerKonnektoren" }
    var slot: String
    var ordnername: String
    var relativerPfad: String
    var schemaVersion: Int
    var updatedAt: Double

    init(from k: OrdnerKonnektor, now: Double) {
        slot = k.slot.rawValue; ordnername = k.ordnername
        relativerPfad = k.relativerPfad; schemaVersion = k.schemaVersion; updatedAt = now
    }
    var toDomain: OrdnerKonnektor? {
        guard let s = OrdnerSlot(rawValue: slot) else { return nil }
        return OrdnerKonnektor(slot: s, ordnername: ordnername, relativerPfad: relativerPfad, schemaVersion: schemaVersion)
    }
}

private struct NomenklaturConfigRow: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "nomenklaturConfig" }
    var key: String
    var value: String
    var updatedAt: Double
}

private struct ProjektKostenstellenRow: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case projectNumber = "projektNummer", namenJSON, updatedAt }

    static var databaseTableName: String { "projektKostenstellen" }
    var projectNumber: String
    var namenJSON: String
    var updatedAt: Double
}

@MainActor
@Observable
public final class NomenklaturStore {
    public private(set) var konnektoren: [OrdnerSlot: OrdnerKonnektor] = [:]
    public private(set) var aktiveSchemaVersion: Int = FolderSchema.v2.version
    public private(set) var authorityMode: NumberAuthorityMode = .local

    public private(set) var customFolderSchema: FolderSchema?

    public private(set) var kostenstellenOverrides: [String: [Kostenstelle]] = [:]
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    private static let schemaVersionKey = "blockC.activeFolderSchemaVersion"
    private static let authorityModeKey = "blockC.numberAuthorityMode"
    private static let customFolderSchemaKey = "blockC.customFolderSchemaJSON"

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func load() throws {
        let records = try db.read { try OrdnerKonnektorRecord.fetchAll($0) }
        konnektoren = Dictionary(uniqueKeysWithValues: records.compactMap(\.toDomain).map { ($0.slot, $0) })
        try ergaenzeFehlendeKonnektoren()

        if let row = try db.read({ try NomenklaturConfigRow.fetchOne($0, key: Self.schemaVersionKey) }),
           let v = Int(row.value) { aktiveSchemaVersion = v }
        if let row = try db.read({ try NomenklaturConfigRow.fetchOne($0, key: Self.authorityModeKey) }),
           let m = NumberAuthorityMode(rawValue: row.value) { authorityMode = m }
        if let row = try db.read({ try NomenklaturConfigRow.fetchOne($0, key: Self.customFolderSchemaKey) }),
           let data = row.value.data(using: .utf8) {
            customFolderSchema = try JSONDecoder().decode(FolderSchema.self, from: data)
        }

        let ksRows = try db.read { try ProjektKostenstellenRow.fetchAll($0) }
        var overrides: [String: [Kostenstelle]] = [:]
        for row in ksRows {
            guard let data = row.namenJSON.data(using: .utf8) else { continue }
            do {
                let namen = try JSONDecoder().decode([String].self, from: data)
                if namen.isEmpty == false { overrides[row.projectNumber] = namen.map { Kostenstelle(name: $0) } }
            } catch {
                MykLog.lifecycle.error("Kostenstellen-Override für \(row.projectNumber, privacy: .public) nicht dekodierbar: \(String(describing: error), privacy: .public)")
            }
        }
        kostenstellenOverrides = overrides
    }

    private func ergaenzeFehlendeKonnektoren() throws {
        let fehlende = OrdnerKonnektor.v2Defaults.filter { konnektoren[$0.slot] == nil }
        guard fehlende.isEmpty == false else { return }
        let ts = Date().timeIntervalSince1970
        try db.write { dbc in
            for k in fehlende { try OrdnerKonnektorRecord(from: k, now: ts).insert(dbc) }
        }
        for k in fehlende { konnektoren[k.slot] = k }
    }

    public func konnektor(_ slot: OrdnerSlot) -> OrdnerKonnektor? { konnektoren[slot] }

    public func aktivesSchema() -> FolderSchema { customFolderSchema ?? .v2 }

    public func kostenstellen(fuer projectNumber: String) -> [Kostenstelle] {
        let o = kostenstellenOverrides[projectNumber]
        return (o?.isEmpty == false) ? o! : Kostenstelle.defaults
    }

    public func kostenstellenProvider() -> KostenstellenProviding {
        DefaultKostenstellenProvider(overrides: kostenstellenOverrides)
    }

    public func setzeKostenstellen(_ namen: [String], fuer projectNumber: String) throws {
        let bereinigt = namen.map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.isEmpty == false }
        guard bereinigt.isEmpty == false else {
            try db.write { dbc in _ = try ProjektKostenstellenRow.deleteOne(dbc, key: projectNumber) }
            kostenstellenOverrides[projectNumber] = nil
            return
        }
        let json = (try? JSONEncoder().encode(bereinigt)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let ts = Date().timeIntervalSince1970
        saveState = .saving
        do {
            try db.write { dbc in
                try ProjektKostenstellenRow(projectNumber: projectNumber, namenJSON: json, updatedAt: ts).save(dbc)
            }
            kostenstellenOverrides[projectNumber] = bereinigt.map { Kostenstelle(name: $0) }
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}
