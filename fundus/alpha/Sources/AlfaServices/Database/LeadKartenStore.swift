import Foundation
import GRDB

public struct LeadKarteRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case projectNumber = "projektNummer", taskID, status, aktualisiertAm }

    public static var databaseTableName: String { "leadKarten" }

    public var projectNumber: String
    public var taskID: String
    public var status: String
    public var aktualisiertAm: Double
    public var id: String { projectNumber }

    public init(projectNumber: String, taskID: String, status: String, aktualisiertAm: Double) {
        self.projectNumber = projectNumber
        self.taskID = taskID
        self.status = status
        self.aktualisiertAm = aktualisiertAm
    }
}

public actor LeadKartenStore {
    public static let statusOffen = "offen"
    public static let statusBelebt = "belebt"
    public static let statusVerloren = "verloren"

    private let db: GRDBDatabase
    public init(db: GRDBDatabase) { self.db = db }

    public func merke(projectNumber: String, taskID: String,
                      status: String = LeadKartenStore.statusOffen) throws {
        let record = LeadKarteRecord(projectNumber: projectNumber, taskID: taskID,
                                     status: status,
                                     aktualisiertAm: Date().timeIntervalSince1970)
        try db.write { conn in try record.save(conn) }
    }

    public func card(projectNumber: String) throws -> LeadKarteRecord? {
        try db.read { conn in try LeadKarteRecord.fetchOne(conn, key: projectNumber) }
    }

    public func setzeStatus(projectNumber: String, status: String) throws {
        guard var record = try card(projectNumber: projectNumber) else { return }
        record.status = status
        record.aktualisiertAm = Date().timeIntervalSince1970
        try db.write { conn in try record.save(conn) }
    }

    public func alleKarten() throws -> [LeadKarteRecord] {
        try db.read { conn in try LeadKarteRecord.fetchAll(conn) }
    }

    public func importiere(_ record: LeadKarteRecord) throws {
        try db.write { conn in try record.save(conn) }
    }
}
