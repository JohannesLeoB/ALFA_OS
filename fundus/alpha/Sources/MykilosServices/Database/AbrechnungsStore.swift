import Foundation
import GRDB
import MykilosKit

public struct AbrechnungsLeistungRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", art, aktualisiertAm, json }

    public static var databaseTableName: String { "abrechnungsLeistungen" }

    public var id: String
    public var projectNumber: String
    public var art: String
    public var aktualisiertAm: Double
    public var json: String

    public init(id: String, projectNumber: String, art: String,
                aktualisiertAm: Double, json: String) {
        self.id = id
        self.projectNumber = projectNumber
        self.art = art
        self.aktualisiertAm = aktualisiertAm
        self.json = json
    }
}

public actor AbrechnungsStore {
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

    public func speichere(_ leistung: AbrechenbareLeistung) throws {
        let data = try encoder.encode(leistung)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "AbrechnungsStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Leistung nicht kodierbar."])
        }
        let record = AbrechnungsLeistungRecord(
            id: leistung.id,
            projectNumber: leistung.projectNumber,
            art: leistung.art.rawValue,
            aktualisiertAm: Date().timeIntervalSince1970,
            json: json)
        try db.write { conn in try record.save(conn) }
    }

    public func alle(projectNumber: String) throws -> (leistungen: [AbrechenbareLeistung], defekte: Int) {
        let records = try db.read { conn in
            try AbrechnungsLeistungRecord
                .filter(Column("projektNummer") == projectNumber)
                .order(Column("aktualisiertAm").desc)
                .fetchAll(conn)
        }
        var leistungen: [AbrechenbareLeistung] = []
        var defekte = 0
        for record in records {
            if let leistung = try? decoder.decode(AbrechenbareLeistung.self, from: Data(record.json.utf8)) {
                leistungen.append(leistung)
            } else {
                defekte += 1
            }
        }
        return (leistungen, defekte)
    }

    public func alle() throws -> (leistungen: [AbrechenbareLeistung], defekte: Int) {
        let records = try db.read { conn in
            try AbrechnungsLeistungRecord.order(Column("aktualisiertAm").desc).fetchAll(conn)
        }
        var leistungen: [AbrechenbareLeistung] = []
        var defekte = 0
        for record in records {
            if let leistung = try? decoder.decode(AbrechenbareLeistung.self, from: Data(record.json.utf8)) {
                leistungen.append(leistung)
            } else {
                defekte += 1
            }
        }
        return (leistungen, defekte)
    }

    public func loesche(id: String) throws {
        _ = try db.write { conn in try AbrechnungsLeistungRecord.deleteOne(conn, key: id) }
    }

    public func aktualisiertAmMap(projectNumber: String) throws -> [String: Double] {
        let records = try db.read { conn in
            try AbrechnungsLeistungRecord.filter(Column("projektNummer") == projectNumber).fetchAll(conn)
        }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.aktualisiertAm) })
    }

    public func importiere(_ leistung: AbrechenbareLeistung, aktualisiertAm: Double) throws {
        let data = try encoder.encode(leistung)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "AbrechnungsStore", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Import nicht kodierbar."])
        }
        let record = AbrechnungsLeistungRecord(
            id: leistung.id, projectNumber: leistung.projectNumber,
            art: leistung.art.rawValue, aktualisiertAm: aktualisiertAm, json: json)
        try db.write { conn in try record.save(conn) }
    }
}
