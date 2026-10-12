import Foundation
import GRDB
import MykilosKit

public struct KonfigEntwurfRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, erstelltAm, geaendertAm, projectNumber = "projektNummer", variantenName, status, dokumentJSON }

    public static var databaseTableName: String { "konfigEntwurf" }

    public var id: String
    public var erstelltAm: Double
    public var geaendertAm: Double
    public var projectNumber: String
    public var variantenName: String
    public var status: String
    public var dokumentJSON: String

    public init(id: String, erstelltAm: Double, geaendertAm: Double, projectNumber: String,
                variantenName: String, status: String, dokumentJSON: String) {
        self.id = id
        self.erstelltAm = erstelltAm
        self.geaendertAm = geaendertAm
        self.projectNumber = projectNumber
        self.variantenName = variantenName
        self.status = status
        self.dokumentJSON = dokumentJSON
    }
}

public actor KonfigEntwurfStore {
    private let db: GRDBDatabase
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(db: GRDBDatabase) {
        self.db = db
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    public func speichere(_ entwurf: KonfigEntwurf) throws {
        let json = try encoder.encode(entwurf)
        guard let jsonText = String(data: json, encoding: .utf8) else {
            throw DatabaseError(message: "KonfigEntwurf nicht als UTF-8 kodierbar")
        }
        let record = KonfigEntwurfRecord(
            id: entwurf.id.uuidString,
            erstelltAm: entwurf.erstelltAm.timeIntervalSince1970,
            geaendertAm: entwurf.geaendertAm.timeIntervalSince1970,
            projectNumber: entwurf.projectNumber,
            variantenName: entwurf.variantenName,
            status: entwurf.status.rawValue,
            dokumentJSON: jsonText
        )
        try db.write { conn in try record.save(conn) }
    }

    public func entwuerfe(projectNumber: String) throws -> [KonfigEntwurf] {
        let records = try db.read { conn in
            try KonfigEntwurfRecord
                .filter(Column("projektNummer") == projectNumber)
                .order(Column("variantenName").asc)
                .fetchAll(conn)
        }
        return try records.map { try dekodiere($0) }
    }

    public func juengste(limit: Int) throws -> [KonfigEntwurf] {
        let records = try db.read { conn in
            try KonfigEntwurfRecord
                .order(Column("geaendertAm").desc)
                .limit(max(1, limit))
                .fetchAll(conn)
        }
        return try records.map { try dekodiere($0) }
    }

    public func entwurf(id: UUID) throws -> KonfigEntwurf? {
        let record = try db.read { conn in
            try KonfigEntwurfRecord.fetchOne(conn, key: id.uuidString)
        }
        guard let record else { return nil }
        return try dekodiere(record)
    }

    public func loesche(id: UUID) throws {
        _ = try db.write { conn in try KonfigEntwurfRecord.deleteOne(conn, key: id.uuidString) }
    }

    public func count() throws -> Int {
        try db.read { conn in try KonfigEntwurfRecord.fetchCount(conn) }
    }

    private func dekodiere(_ record: KonfigEntwurfRecord) throws -> KonfigEntwurf {
        guard let data = record.dokumentJSON.data(using: .utf8) else {
            throw DatabaseError(message: "KonfigEntwurf-JSON nicht lesbar (id \(record.id))")
        }
        return try decoder.decode(KonfigEntwurf.self, from: data)
    }
}
