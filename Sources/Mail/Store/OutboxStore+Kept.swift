import Foundation
import GRDB
import Hub

extension OutboxStore {
    public var keptDrafts: [KeptDraft] {
        (try? database.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM mail_draft ORDER BY updatedAt").compactMap(Self.kept)
        }) ?? []
    }

    public func keep(_ kept: KeptDraft) {
        guard let data = try? JSONEncoder().encode(kept.draft) else { return }
        let id = kept.id.uuidString
        let inlet = kept.inlet
        let remoteID = kept.remoteID
        let mirrorID = kept.mirrorID
        let at = kept.updatedAt.timeIntervalSince1970
        _ = try? database.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO mail_draft (id, inlet, draft, remoteID, mirrorID, updatedAt) VALUES (?, ?, ?, ?, ?, ?)",
                           arguments: [id, inlet, data, remoteID, mirrorID, at])
        }
    }

    public func dropKept(_ id: UUID) {
        let key = id.uuidString
        _ = try? database.write { db in
            try db.execute(sql: "DELETE FROM mail_draft WHERE id = ?", arguments: [key])
        }
    }

    nonisolated private static func kept(_ row: Row) -> KeptDraft? {
        guard let id = UUID(uuidString: row["id"]),
              let draft = try? JSONDecoder().decode(Draft.self, from: row["draft"] as Data) else { return nil }
        return KeptDraft(id: id, inlet: row["inlet"], draft: draft, remoteID: row["remoteID"], mirrorID: row["mirrorID"],
                         updatedAt: Date(timeIntervalSince1970: row["updatedAt"]))
    }
}
