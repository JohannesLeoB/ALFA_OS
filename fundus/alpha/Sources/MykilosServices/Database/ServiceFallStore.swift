import Foundation
import GRDB
import MykilosKit

public struct ServiceFallRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", status, aktualisiertAm, json }

    public static var databaseTableName: String { "servicefaelle" }

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

public actor ServiceFallStore {
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

    public func speichere(_ fall: ServiceFall) throws {
        let record = try baueRecord(fall, aktualisiertAm: Date().timeIntervalSince1970)
        try db.write { conn in try record.save(conn) }
    }

    public func alle(projectNumber: String) throws -> (faelle: [ServiceFall], defekte: Int) {
        let records = try db.read { conn in
            try ServiceFallRecord
                .filter(Column("projektNummer") == projectNumber)
                .order(Column("aktualisiertAm").desc)
                .fetchAll(conn)
        }
        var faelle: [ServiceFall] = []
        var defekte = 0
        for record in records {
            if let f = try? decoder.decode(ServiceFall.self, from: Data(record.json.utf8)) {
                faelle.append(f)
            } else {
                defekte += 1
            }
        }
        return (faelle, defekte)
    }

    public func alle() throws -> (faelle: [ServiceFall], defekte: Int) {
        let records = try db.read { conn in
            try ServiceFallRecord.order(Column("aktualisiertAm").desc).fetchAll(conn)
        }
        var faelle: [ServiceFall] = []
        var defekte = 0
        for record in records {
            if let f = try? decoder.decode(ServiceFall.self, from: Data(record.json.utf8)) {
                faelle.append(f)
            } else {
                defekte += 1
            }
        }
        return (faelle, defekte)
    }

    public func loesche(id: String) throws {
        _ = try db.write { conn in try ServiceFallRecord.deleteOne(conn, key: id) }
    }

    public func aktualisiertAmMap(projectNumber: String) throws -> [String: Double] {
        let records = try db.read { conn in
            try ServiceFallRecord.filter(Column("projektNummer") == projectNumber).fetchAll(conn)
        }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.aktualisiertAm) })
    }

    public func importiere(_ fall: ServiceFall, aktualisiertAm: Double) throws {
        let record = try baueRecord(fall, aktualisiertAm: aktualisiertAm)
        try db.write { conn in try record.save(conn) }
    }

    private func baueRecord(_ fall: ServiceFall, aktualisiertAm: Double) throws -> ServiceFallRecord {
        let data = try encoder.encode(fall)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ServiceFallStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Servicefall nicht kodierbar."])
        }
        return ServiceFallRecord(id: fall.id, projectNumber: fall.projectNumber,
                                 status: fall.status.rawValue, aktualisiertAm: aktualisiertAm, json: json)
    }
}
