import Foundation
import GRDB
import MykilosKit

public struct BestellRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", status, aktualisiertAm, json }

    public static var databaseTableName: String { "bestellungen" }

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

public actor BestellStore {
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

    public func speichere(_ bestellung: Order) throws {
        let data = try encoder.encode(bestellung)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "BestellStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Order nicht kodierbar."])
        }
        let record = BestellRecord(
            id: bestellung.id,
            projectNumber: bestellung.projectNumber,
            status: bestellung.status.rawValue,
            aktualisiertAm: Date().timeIntervalSince1970,
            json: json)
        try db.write { conn in try record.save(conn) }
    }

    public func alle(projectNumber: String) throws -> (bestellungen: [Order], defekte: Int) {
        let records = try db.read { conn in
            try BestellRecord
                .filter(Column("projektNummer") == projectNumber)
                .order(Column("aktualisiertAm").desc)
                .fetchAll(conn)
        }
        var bestellungen: [Order] = []
        var defekte = 0
        for record in records {
            if let bestellung = try? decoder.decode(Order.self, from: Data(record.json.utf8)) {
                bestellungen.append(bestellung)
            } else {
                defekte += 1
            }
        }
        return (bestellungen, defekte)
    }

    public func loesche(id: String) throws {
        _ = try db.write { conn in try BestellRecord.deleteOne(conn, key: id) }
    }

    public func aktualisiertAmMap(projectNumber: String) throws -> [String: Double] {
        let records = try db.read { conn in
            try BestellRecord.filter(Column("projektNummer") == projectNumber).fetchAll(conn)
        }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.aktualisiertAm) })
    }

    public func importiere(_ bestellung: Order, aktualisiertAm: Double) throws {
        let data = try encoder.encode(bestellung)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "BestellStore", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Import nicht kodierbar."])
        }
        let record = BestellRecord(
            id: bestellung.id, projectNumber: bestellung.projectNumber,
            status: bestellung.status.rawValue, aktualisiertAm: aktualisiertAm, json: json)
        try db.write { conn in try record.save(conn) }
    }
}
