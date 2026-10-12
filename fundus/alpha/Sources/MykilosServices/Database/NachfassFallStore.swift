import Foundation
import GRDB
import MykilosKit

public struct NachfassFallRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, customerName = "kundeName", customerNumber = "kundennummer", status, naechstesNachfassen, value = "wert", aktualisiertAm, json }

    public static var databaseTableName: String { "nachfassfaelle" }

    public var id: String
    public var customerName: String
    public var customerNumber: String?
    public var status: String
    public var naechstesNachfassen: Double?
    public var value: Double?
    public var aktualisiertAm: Double
    public var json: String

    public init(id: String, customerName: String, customerNumber: String?, status: String,
                naechstesNachfassen: Double?, value: Double?, aktualisiertAm: Double, json: String) {
        self.id = id
        self.customerName = customerName
        self.customerNumber = customerNumber
        self.status = status
        self.naechstesNachfassen = naechstesNachfassen
        self.value = value
        self.aktualisiertAm = aktualisiertAm
        self.json = json
    }
}

public actor NachfassFallStore {
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

    public func speichere(_ fall: NachfassFall) throws {
        let record = try baueRecord(fall, aktualisiertAm: Date().timeIntervalSince1970)
        try db.write { conn in try record.save(conn) }
    }

    public func speichereAlle(_ faelle: [NachfassFall]) throws {
        let stamp = Date().timeIntervalSince1970
        let records = try faelle.map { try baueRecord($0, aktualisiertAm: stamp) }
        try db.write { conn in for r in records { try r.save(conn) } }
    }

    public func alle() throws -> (faelle: [NachfassFall], defekte: Int) {
        let records = try db.read { conn in
            try NachfassFallRecord.order(Column("aktualisiertAm").desc).fetchAll(conn)
        }
        var faelle: [NachfassFall] = []
        var defekte = 0
        for record in records {
            if let f = try? decoder.decode(NachfassFall.self, from: Data(record.json.utf8)) {
                faelle.append(f)
            } else {
                defekte += 1
            }
        }
        return (faelle, defekte)
    }

    public func vorhandeneIDs() throws -> Set<String> {
        let ids = try db.read { conn in
            try String.fetchAll(conn, sql: "SELECT id FROM nachfassfaelle")
        }
        return Set(ids)
    }

    public func count() throws -> Int {
        try db.read { conn in try NachfassFallRecord.fetchCount(conn) }
    }

    public func loesche(id: String) throws {
        _ = try db.write { conn in try NachfassFallRecord.deleteOne(conn, key: id) }
    }

    public func aktualisiertAmMap() throws -> [String: Double] {
        let records = try db.read { conn in try NachfassFallRecord.fetchAll(conn) }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.aktualisiertAm) })
    }

    public func importiere(_ fall: NachfassFall, aktualisiertAm: Double) throws {
        let record = try baueRecord(fall, aktualisiertAm: aktualisiertAm)
        try db.write { conn in try record.save(conn) }
    }

    private func baueRecord(_ fall: NachfassFall, aktualisiertAm: Double) throws -> NachfassFallRecord {
        let data = try encoder.encode(fall)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "NachfassFallStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Nachfass-Fall nicht kodierbar."])
        }
        return NachfassFallRecord(
            id: fall.id, customerName: fall.customerName, customerNumber: fall.customerNumber,
            status: fall.status.rawValue,
            naechstesNachfassen: fall.naechstesNachfassen?.timeIntervalSince1970,
            value: fall.value, aktualisiertAm: aktualisiertAm, json: json)
    }
}
