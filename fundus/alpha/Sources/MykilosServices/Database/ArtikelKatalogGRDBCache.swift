import Foundation
import GRDB
import MykilosKit

public struct ArtikelKatalogGRDBCache: Sendable {
    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func count() throws -> Int {
        try db.read { grdb in
            try Int.fetchOne(grdb, sql: "SELECT COUNT(*) FROM artikelKatalog") ?? 0
        }
    }

    public func alle() throws -> [ArtikelItem] {
        try db.read { grdb in
            try String.fetchAll(grdb, sql: "SELECT itemJSON FROM artikelKatalog ORDER BY artikelnummer")
                .compactMap(Self.decode)
        }
    }

    public func suche(term: String, limit: Int = 200) throws -> [ArtikelItem] {
        let tokens = ArtikelItem.tokenize(term)
        return try db.read { grdb in
            if tokens.isEmpty {
                return try String.fetchAll(grdb,
                    sql: "SELECT itemJSON FROM artikelKatalog ORDER BY artikelnummer LIMIT ?",
                    arguments: [limit]).compactMap(Self.decode)
            }

            let match = tokens.map { "\($0)*" }.joined(separator: " ")
            return try String.fetchAll(grdb, sql: """
                SELECT k.itemJSON FROM artikelKatalog k
                JOIN artikelKatalogFTS f ON f.rowid = k.rowid
                WHERE artikelKatalogFTS MATCH ?
                ORDER BY bm25(artikelKatalogFTS)
                LIMIT ?
                """, arguments: [match, limit]).compactMap(Self.decode)
        }
    }

    public func ersetzeAlle(_ items: [ArtikelItem]) throws {
        try db.write { grdb in
            try grdb.execute(sql: "DELETE FROM artikelKatalog")
            for item in items { try Self.upsert(item, in: grdb) }
        }
    }

    public func upsert(_ items: [ArtikelItem]) throws {
        guard !items.isEmpty else { return }
        try db.write { grdb in
            for item in items { try Self.upsert(item, in: grdb) }
        }
    }

    public func zuletztGesynctISO() throws -> String? {
        try db.read { grdb in
            try String.fetchOne(grdb, sql: "SELECT zuletztGesynctISO FROM artikelKatalogSync WHERE id = 1")
        }
    }

    public func setzeZuletztGesynct(_ iso: String) throws {
        try db.write { grdb in
            try grdb.execute(sql: """
                INSERT INTO artikelKatalogSync (id, zuletztGesynctISO) VALUES (1, ?)
                ON CONFLICT(id) DO UPDATE SET zuletztGesynctISO = excluded.zuletztGesynctISO
                """, arguments: [iso])
        }
    }

    public func entferne(ids: [String]) throws {
        guard !ids.isEmpty else { return }
        try db.write { grdb in
            let platzhalter = ids.map { _ in "?" }.joined(separator: ",")
            try grdb.execute(sql: "DELETE FROM artikelKatalog WHERE id IN (\(platzhalter))",
                             arguments: StatementArguments(ids))
        }
    }

    private static func upsert(_ item: ArtikelItem, in grdb: Database) throws {
        let suchtext = item.suchTokens.joined(separator: " ")
        try grdb.execute(sql: """
            INSERT INTO artikelKatalog (id, artikelnummer, hersteller, kategorie, suchtext, itemJSON)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                artikelnummer = excluded.artikelnummer,
                hersteller    = excluded.hersteller,
                kategorie     = excluded.kategorie,
                suchtext      = excluded.suchtext,
                itemJSON      = excluded.itemJSON
            """,
            arguments: [item.id, item.articleNumber, item.hersteller, item.kategorie,
                        suchtext, Self.encode(item)])
    }

    private static func encode(_ item: ArtikelItem) -> String {
        (try? String(data: JSONEncoder().encode(item), encoding: .utf8)) ?? "{}"
    }

    private static func decode(_ json: String) -> ArtikelItem? {
        try? JSONDecoder().decode(ArtikelItem.self, from: Data(json.utf8))
    }
}
