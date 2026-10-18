import Foundation
import GRDB
import AlfaKit

public struct TelefonnotizRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", date = "datum", json }

    public static var databaseTableName: String { "telefonnotizen" }

    public var id: String
    public var projectNumber: String
    public var date: Double
    public var json: String

    public init(id: String, projectNumber: String, date: Double, json: String) {
        self.id = id
        self.projectNumber = projectNumber
        self.date = date
        self.json = json
    }
}

public actor TelefonnotizStore {
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

    public func speichere(_ notiz: Telefonnotiz) throws {
        let data = try encoder.encode(notiz)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "TelefonnotizStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Telefonnotiz nicht kodierbar."])
        }
        let record = TelefonnotizRecord(
            id: notiz.id,
            projectNumber: notiz.projectNumber,
            date: notiz.date.timeIntervalSince1970,
            json: json)
        try db.write { conn in try record.save(conn) }
    }

    public func alle(projectNumber: String) throws -> (notizen: [Telefonnotiz], defekte: Int) {
        let records = try db.read { conn in
            try TelefonnotizRecord
                .filter(Column("projektNummer") == projectNumber)
                .order(Column("datum").desc)
                .fetchAll(conn)
        }
        var notizen: [Telefonnotiz] = []
        var defekte = 0
        for record in records {
            if let notiz = try? decoder.decode(Telefonnotiz.self, from: Data(record.json.utf8)) {
                notizen.append(notiz)
            } else {
                defekte += 1
            }
        }
        return (notizen, defekte)
    }

    public func loesche(id: String) throws {
        _ = try db.write { conn in try TelefonnotizRecord.deleteOne(conn, key: id) }
    }

    public func datumMap(projectNumber: String) throws -> [String: Double] {
        let records = try db.read { conn in
            try TelefonnotizRecord.filter(Column("projektNummer") == projectNumber).fetchAll(conn)
        }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.date) })
    }
}
