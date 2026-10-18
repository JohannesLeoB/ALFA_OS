import Foundation
import GRDB
import AlfaKit

public struct MeilensteinRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", status, date = "datum", aktualisiertAm, json }

    public static var databaseTableName: String { "meilensteine" }

    public var id: String
    public var projectNumber: String
    public var status: String
    public var date: Double
    public var aktualisiertAm: Double
    public var json: String

    public init(id: String, projectNumber: String, status: String,
                date: Double, aktualisiertAm: Double, json: String) {
        self.id = id
        self.projectNumber = projectNumber
        self.status = status
        self.date = date
        self.aktualisiertAm = aktualisiertAm
        self.json = json
    }
}

public actor MeilensteinStore {
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

    public func speichere(_ m: Meilenstein) throws {
        let record = try baueRecord(m, aktualisiertAm: Date().timeIntervalSince1970)
        try db.write { conn in try record.save(conn) }
    }

    public func alle(projectNumber: String) throws -> (meilensteine: [Meilenstein], defekte: Int) {
        let records = try db.read { conn in
            try MeilensteinRecord
                .filter(Column("projektNummer") == projectNumber)
                .order(Column("datum").asc)
                .fetchAll(conn)
        }
        return dekodiere(records)
    }

    public func fensterBis(_ grenze: Date) throws -> [Meilenstein] {
        let records = try db.read { conn in
            try MeilensteinRecord
                .filter(Column("datum") < grenze.timeIntervalSince1970)
                .order(Column("datum").asc)
                .fetchAll(conn)
        }
        return dekodiere(records).meilensteine.filter { $0.status.istOffen }
    }

    public func loesche(id: String) throws {
        _ = try db.write { conn in try MeilensteinRecord.deleteOne(conn, key: id) }
    }

    public func aktualisiertAmMap(projectNumber: String) throws -> [String: Double] {
        let records = try db.read { conn in
            try MeilensteinRecord.filter(Column("projektNummer") == projectNumber).fetchAll(conn)
        }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.aktualisiertAm) })
    }

    public func importiere(_ m: Meilenstein, aktualisiertAm: Double) throws {
        let record = try baueRecord(m, aktualisiertAm: aktualisiertAm)
        try db.write { conn in try record.save(conn) }
    }

    private func dekodiere(_ records: [MeilensteinRecord]) -> (meilensteine: [Meilenstein], defekte: Int) {
        var out: [Meilenstein] = []
        var defekte = 0
        for record in records {
            if let m = try? decoder.decode(Meilenstein.self, from: Data(record.json.utf8)) {
                out.append(m)
            } else {
                defekte += 1
            }
        }
        return (out, defekte)
    }

    private func baueRecord(_ m: Meilenstein, aktualisiertAm: Double) throws -> MeilensteinRecord {
        let data = try encoder.encode(m)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "MeilensteinStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Meilenstein nicht kodierbar."])
        }
        return MeilensteinRecord(id: m.id, projectNumber: m.projectNumber, status: m.status.rawValue,
                                 date: m.date.timeIntervalSince1970, aktualisiertAm: aktualisiertAm, json: json)
    }
}
