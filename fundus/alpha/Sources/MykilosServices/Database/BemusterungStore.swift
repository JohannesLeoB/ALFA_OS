import Foundation
import GRDB
import MykilosKit

public struct BemusterungRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", status, aktualisiertAm, json }

    public static var databaseTableName: String { "bemusterungen" }

    public var id: String
    public var projectNumber: String
    public var status: String
    public var aktualisiertAm: Double
    public var json: String

    public init(id: String, projectNumber: String, status: String,
                aktualisiertAm: Double, json: String) {
        self.id = id
        self.projectNumber = projectNumber
        self.status = status
        self.aktualisiertAm = aktualisiertAm
        self.json = json
    }
}

public actor BemusterungStore {
    private let db: GRDBDatabase
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    public init(db: GRDBDatabase) {
        self.db = db
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
        decoder.dateDecodingStrategy = .iso8601
    }

    public func speichere(_ muster: BemusterungsMuster) throws {
        let record = try baueRecord(muster, aktualisiertAm: Date().timeIntervalSince1970)
        try db.write { conn in try record.save(conn) }
    }

    public func speichereAlle(_ muster: [BemusterungsMuster]) throws {
        let stamp = Date().timeIntervalSince1970
        let records = try muster.map { try baueRecord($0, aktualisiertAm: stamp) }
        try db.write { conn in for r in records { try r.save(conn) } }
    }

    public func alle(projectNumber: String) throws -> (muster: [BemusterungsMuster], defekte: Int) {
        let records = try db.read { conn in
            try BemusterungRecord
                .filter(Column("projektNummer") == projectNumber)
                .order(Column("aktualisiertAm").desc)
                .fetchAll(conn)
        }
        var muster: [BemusterungsMuster] = []
        var defekte = 0
        for record in records {
            if let m = try? decoder.decode(BemusterungsMuster.self, from: Data(record.json.utf8)) {
                muster.append(m)
            } else {
                defekte += 1
            }
        }
        return (muster, defekte)
    }

    public func loesche(id: String) throws {
        _ = try db.write { conn in try BemusterungRecord.deleteOne(conn, key: id) }
    }

    public func aktualisiertAmMap(projectNumber: String) throws -> [String: Double] {
        let records = try db.read { conn in
            try BemusterungRecord.filter(Column("projektNummer") == projectNumber).fetchAll(conn)
        }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.aktualisiertAm) })
    }

    public func importiere(_ muster: BemusterungsMuster, aktualisiertAm: Double) throws {
        let record = try baueRecord(muster, aktualisiertAm: aktualisiertAm)
        try db.write { conn in try record.save(conn) }
    }

    private func baueRecord(_ muster: BemusterungsMuster, aktualisiertAm: Double) throws -> BemusterungRecord {
        let data = try encoder.encode(muster)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "BemusterungStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Muster nicht kodierbar."])
        }
        return BemusterungRecord(id: muster.id, projectNumber: muster.projectNumber,
                                 status: muster.status.rawValue, aktualisiertAm: aktualisiertAm, json: json)
    }
}
