import Foundation
import GRDB
import AlfaKit

struct KontaktLokalRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "kontaktLokal" }
    var id: String
    var name: String
    var organisation: String?
    var email: String?
    var telefon: String?
    var adresse: String?
    var projekt: String?
    var kategorie: String?
    var vorname: String?
    var nachname: String?
    var photoURL: String?
    var herkunft: String
    var aktualisiertAm: Double

    init(from k: StudioContact, herkunft: String, aktualisiertAm: Double) {
        id = k.id; name = k.name; organisation = k.organisation; email = k.email
        telefon = k.telefon; adresse = k.adresse; projekt = k.projekt; kategorie = k.kategorie
        vorname = k.vorname; nachname = k.nachname; photoURL = k.photoURL
        self.herkunft = herkunft; self.aktualisiertAm = aktualisiertAm
    }

    var toDomain: StudioContact {
        StudioContact(id: id, name: name, organisation: organisation, email: email,
                      telefon: telefon, adresse: adresse, projekt: projekt, kategorie: kategorie,
                      vorname: vorname, nachname: nachname, photoURL: photoURL)
    }
}

public actor KontaktStore {
    private let db: GRDBDatabase
    public init(db: GRDBDatabase) { self.db = db }

    public func alle() throws -> [StudioContact] {
        let rows = try db.read { conn in try KontaktLokalRecord.fetchAll(conn) }
        let airtable = rows.filter { $0.herkunft == "airtable" }.map(\.toDomain)
        let lokal    = rows.filter { $0.herkunft == "lokal" }.map(\.toDomain)
        let override = rows.filter { $0.herkunft == "override" }.map(\.toDomain)
        let vereint = KontaktMerge.vereinige(airtable: airtable, lokal: lokal)
        return KontaktMerge.wendeUeberschreibungenAn(basis: vereint, ueberschreibungen: override)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func ersetzeAirtableStand(_ frisch: [StudioContact], jetzt: Double) throws {
        try db.write { conn in
            try KontaktLokalRecord.filter(Column("herkunft") == "airtable").deleteAll(conn)
            for k in frisch {
                try KontaktLokalRecord(from: k, herkunft: "airtable", aktualisiertAm: jetzt).insert(conn)
            }
        }
    }

    public func dublettenFuer(_ kandidat: StudioContact) throws -> [StudioContact] {
        let stock = try alle()
        return KontaktMerge.findeDubletten(kandidat: kandidat, stock: stock)
    }

    public func legeLokalAn(_ k: StudioContact, jetzt: Double) throws {
        try db.write { conn in
            try KontaktLokalRecord(from: k, herkunft: "lokal", aktualisiertAm: jetzt).save(conn)
        }
    }

    public func setzeUeberschreibung(_ k: StudioContact, jetzt: Double) throws {
        try db.write { conn in
            try KontaktLokalRecord(from: k, herkunft: "override", aktualisiertAm: jetzt).save(conn)
        }
    }

    public func stock() throws -> (airtable: Int, lokal: Int, override: Int) {
        try db.read { conn in
            let a = try KontaktLokalRecord.filter(Column("herkunft") == "airtable").fetchCount(conn)
            let l = try KontaktLokalRecord.filter(Column("herkunft") == "lokal").fetchCount(conn)
            let o = try KontaktLokalRecord.filter(Column("herkunft") == "override").fetchCount(conn)
            return (a, l, o)
        }
    }
}
