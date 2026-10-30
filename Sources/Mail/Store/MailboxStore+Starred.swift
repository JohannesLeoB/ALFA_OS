import Foundation
import GRDB
import Hub
import Storage

extension MailboxStore {
    nonisolated private static let starredSelect = """
        SELECT * FROM mail_message WHERE inlet = ?1 AND flags LIKE '%flagged%'
        AND folder NOT IN (SELECT id FROM mail_folder WHERE inlet = ?1 AND role IN ('trash', 'spam'))
        """

    nonisolated static func starredMessages(_ database: SQLiteStore, inlet: Inlet.ID) -> [MessageSummary] {
        (try? database.read { db in
            try Row.fetchAll(db, sql: starredSelect + " ORDER BY receivedAt DESC, id DESC", arguments: [inlet]).map(summary)
        }) ?? []
    }

    func starredMatches(_ inlet: Inlet.ID, query: String) -> [MessageSummary] {
        let pattern = "%" + query.replacingOccurrences(of: "%", with: "") + "%"
        let rows = try? database.read { db in
            try Row.fetchAll(db, sql: Self.starredSelect + """
                 AND (subject LIKE ?2 OR sender LIKE ?2 OR fromRaw LIKE ?2 OR toRaw LIKE ?2 OR ccRaw LIKE ?2 OR snippet LIKE ?2)
                 ORDER BY receivedAt DESC, id DESC
                """, arguments: [inlet, pattern]).map(Self.summary)
        }
        return rows ?? []
    }

    func announceChange(_ inlet: Inlet.ID, _ folder: String) {
        eventBus.emit(.messagesChanged(inlet, folder: folder))
        guard folder != Folder.starredID, folders(inlet).contains(where: { $0.id == Folder.starredID }) else { return }
        eventBus.emit(.messagesChanged(inlet, folder: Folder.starredID))
    }
}
