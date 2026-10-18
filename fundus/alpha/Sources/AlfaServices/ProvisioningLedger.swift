import Foundation
import GRDB
import AlfaKit

private struct ProvisioningLedgerRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case idempotenzSchluessel, projektnummer, kdnr, status, erledigteSchritteJSON, driveProjectFolderId = "driveProjektOrdnerID", driveUnterordnerJSON, airtableRecordID, clickUpListID, lastError = "letzterFehler", updatedAt }

    static var databaseTableName: String { "provisioningLedger" }
    var idempotenzSchluessel: String
    var projektnummer: String
    var kdnr: String
    var status: String
    var erledigteSchritteJSON: String
    var driveProjectFolderId: String?
    var driveUnterordnerJSON: String
    var airtableRecordID: String?
    var clickUpListID: String?
    var lastError: String?
    var updatedAt: Double

    init(from r: ProvisioningResult) {
        idempotenzSchluessel = r.idempotenzSchluessel
        projektnummer = r.projektnummer
        kdnr = r.kdnr
        status = r.status.rawValue
        erledigteSchritteJSON = Self.encode(Array(r.erledigteSchritte).map(\.rawValue))
        driveProjectFolderId = r.driveProjectFolderId
        driveUnterordnerJSON = Self.encode(r.driveUnterordnerIDs)
        airtableRecordID = r.airtableRecordID
        clickUpListID = r.clickUpListID
        lastError = r.lastError
        updatedAt = r.updatedAt.timeIntervalSince1970
    }

    var toDomain: ProvisioningResult {
        let schritte = (Self.decode([String].self, erledigteSchritteJSON) ?? [])
            .compactMap(ProvisioningStep.init(rawValue:))
        return ProvisioningResult(
            idempotenzSchluessel: idempotenzSchluessel, projektnummer: projektnummer, kdnr: kdnr,
            status: ProvisioningStatus(rawValue: status) ?? .offen,
            erledigteSchritte: Set(schritte),
            driveProjectFolderId: driveProjectFolderId,
            driveUnterordnerIDs: Self.decode([String: String].self, driveUnterordnerJSON) ?? [:],
            airtableRecordID: airtableRecordID, clickUpListID: clickUpListID, lastError: lastError,
            updatedAt: Date(timeIntervalSince1970: updatedAt))
    }

    static func encode<T: Encodable>(_ v: T) -> String {
        do {
            let data = try JSONEncoder().encode(v)
            guard let json = String(data: data, encoding: .utf8) else {
                MykLog.lifecycle.error("ProvisioningLedger: UTF8-Dekodierung nach JSON-Encode fehlgeschlagen für \(String(describing: T.self), privacy: .public)")
                return v is [String] ? "[]" : "{}"
            }
            return json
        } catch {
            MykLog.lifecycle.error("ProvisioningLedger: JSON-Encode fehlgeschlagen für \(String(describing: T.self), privacy: .public): \(String(describing: error), privacy: .public)")
            return v is [String] ? "[]" : "{}"
        }
    }
    static func decode<T: Decodable>(_ type: T.Type, _ json: String) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            MykLog.lifecycle.error("ProvisioningLedger: JSON-Decode fehlgeschlagen für \(String(describing: T.self), privacy: .public): \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}

@MainActor
@Observable
public final class ProvisioningLedger {
    public private(set) var saveState: SaveState = .idle
    private let db: GRDBDatabase

    public init(db: GRDBDatabase) { self.db = db }

    public func entry(fuer key: String) throws -> ProvisioningResult? {
        try db.read { try ProvisioningLedgerRecord.fetchOne($0, key: key) }?.toDomain
    }

    public func alle() throws -> [ProvisioningResult] {
        try db.read { try ProvisioningLedgerRecord.order(Column("updatedAt").desc).fetchAll($0) }.map(\.toDomain)
    }

    public func speichere(_ result: ProvisioningResult) throws {
        saveState = .saving
        do {
            var r = result; r.updatedAt = Date()
            try db.write { try ProvisioningLedgerRecord(from: r).save($0) }
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func entferne(key: String) throws {
        try db.write { _ = try ProvisioningLedgerRecord.deleteOne($0, key: key) }
    }
}
