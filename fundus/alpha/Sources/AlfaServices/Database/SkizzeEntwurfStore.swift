import Foundation
import GRDB

public struct SkizzeEntwurfRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, erstelltAm, projectNumber = "projektNummer", title = "titel", dokumentJSON, fotoPNG, imageExtension = "bildEndung" }

    public static var databaseTableName: String { "skizzeEntwurf" }

    public var id: String
    public var erstelltAm: Double
    public var projectNumber: String?
    public var title: String
    public var dokumentJSON: String
    public var fotoPNG: Data?
    public var imageExtension: String?

    public init(id: String, erstelltAm: Double, projectNumber: String?, title: String,
                dokumentJSON: String, fotoPNG: Data?, imageExtension: String?) {
        self.id = id
        self.erstelltAm = erstelltAm
        self.projectNumber = projectNumber
        self.title = title
        self.dokumentJSON = dokumentJSON
        self.fotoPNG = fotoPNG
        self.imageExtension = imageExtension
    }
}

public actor SkizzeEntwurfStore {
    private let db: GRDBDatabase
    private let maxEntwuerfe: Int

    public init(db: GRDBDatabase, maxEntwuerfe: Int = 10) {
        self.db = db
        self.maxEntwuerfe = max(1, maxEntwuerfe)
    }

    @discardableResult
    public func speichere(_ e: SkizzeEntwurfRecord) throws -> [String] {
        try db.write { conn in
            try e.save(conn)

            let imProjekt = e.projectNumber.map { Column("projektNummer") == $0 } ?? (Column("projektNummer") == nil)
            let idsNeuZuerst = try SkizzeEntwurfRecord
                .filter(imProjekt)
                .select(Column("id"), as: String.self)
                .order(Column("erstelltAm").desc)
                .fetchAll(conn)
            let ueberzaehligeIDs = Array(idsNeuZuerst.dropFirst(maxEntwuerfe))
            if ueberzaehligeIDs.isEmpty == false {
                try SkizzeEntwurfRecord
                    .filter(ueberzaehligeIDs.contains(Column("id")))
                    .deleteAll(conn)
            }
            return ueberzaehligeIDs
        }
    }

    public func alle() throws -> [SkizzeEntwurfRecord] {
        try db.read { conn in
            try SkizzeEntwurfRecord.order(Column("erstelltAm").desc).fetchAll(conn)
        }
    }

    public func count() throws -> Int {
        try db.read { conn in try SkizzeEntwurfRecord.fetchCount(conn) }
    }

    public func loesche(id: String) throws {
        _ = try db.write { conn in try SkizzeEntwurfRecord.deleteOne(conn, key: id) }
    }
}
