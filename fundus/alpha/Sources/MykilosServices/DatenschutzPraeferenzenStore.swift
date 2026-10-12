import Foundation
import Observation
import GRDB
import MykilosKit

private struct DatenschutzPraeferenzenRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "datenschutzPraeferenzen"
    static let localID = "local"

    var id: String
    var teileMailMitAssistent: Bool
    var teileKalenderMitAssistent: Bool
    var teileKontakteMitAssistent: Bool
    var teileDriveMitAssistent: Bool
    var teileClickUpMitAssistent: Bool
    var teileNotizenMitAssistent: Bool
    var teileAufgabenMitAssistent: Bool
    var teileKatalogKalkulationMitAssistent: Bool
    var teileStudioWissenMitAssistent: Bool
    var teileChatMitAssistent: Bool
    var teileClockodoMitAssistent: Bool
    var kiKomplettAus: Bool
    var updatedAt: Double

    init(from praeferenzen: DatenschutzPraeferenzen) {
        self.id = Self.localID
        self.teileMailMitAssistent = praeferenzen.teileMailMitAssistent
        self.teileKalenderMitAssistent = praeferenzen.teileKalenderMitAssistent
        self.teileKontakteMitAssistent = praeferenzen.teileKontakteMitAssistent
        self.teileDriveMitAssistent = praeferenzen.teileDriveMitAssistent
        self.teileClickUpMitAssistent = praeferenzen.teileClickUpMitAssistent
        self.teileNotizenMitAssistent = praeferenzen.teileNotizenMitAssistent
        self.teileAufgabenMitAssistent = praeferenzen.teileAufgabenMitAssistent
        self.teileKatalogKalkulationMitAssistent = praeferenzen.teileKatalogKalkulationMitAssistent
        self.teileStudioWissenMitAssistent = praeferenzen.teileStudioWissenMitAssistent
        self.teileChatMitAssistent = praeferenzen.teileChatMitAssistent
        self.teileClockodoMitAssistent = praeferenzen.teileClockodoMitAssistent
        self.kiKomplettAus = praeferenzen.kiKomplettAus
        self.updatedAt = praeferenzen.updatedAt.timeIntervalSince1970
    }

    var toDomain: DatenschutzPraeferenzen {
        DatenschutzPraeferenzen(
            teileMailMitAssistent: teileMailMitAssistent,
            teileKalenderMitAssistent: teileKalenderMitAssistent,
            teileKontakteMitAssistent: teileKontakteMitAssistent,
            teileDriveMitAssistent: teileDriveMitAssistent,
            teileClickUpMitAssistent: teileClickUpMitAssistent,
            teileNotizenMitAssistent: teileNotizenMitAssistent,
            teileAufgabenMitAssistent: teileAufgabenMitAssistent,
            teileKatalogKalkulationMitAssistent: teileKatalogKalkulationMitAssistent,
            teileStudioWissenMitAssistent: teileStudioWissenMitAssistent,
            teileChatMitAssistent: teileChatMitAssistent,
            teileClockodoMitAssistent: teileClockodoMitAssistent,
            kiKomplettAus: kiKomplettAus,
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }
}

@MainActor
@Observable
public final class DatenschutzPraeferenzenStore {
    public private(set) var praeferenzen: DatenschutzPraeferenzen = .standard
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func load() throws {
        let record = try db.read { dbConn in
            try DatenschutzPraeferenzenRecord.fetchOne(dbConn, key: DatenschutzPraeferenzenRecord.localID)
        }
        praeferenzen = record?.toDomain ?? .standard
    }

    public func speichere(_ neu: DatenschutzPraeferenzen) throws {
        saveState = .saving
        do {
            let record = DatenschutzPraeferenzenRecord(from: neu)
            try db.write { dbConn in try record.save(dbConn) }
            praeferenzen = neu
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}
