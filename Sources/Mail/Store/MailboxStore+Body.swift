import Foundation
import GRDB
import Hub

extension MailboxStore {
    func keptBody(_ inlet: Inlet.ID, messageID: String) -> MessageBody? {
        let found = try? database.read { db -> (String?, String?, Data, Data, Data?)? in
            guard let row = try Row.fetchOne(db, sql: "SELECT text, html, images, attachments, unsubscribe FROM mail_body WHERE inlet = ? AND id = ?",
                                             arguments: [inlet, messageID]) else { return nil }
            return (row["text"], row["html"], row["images"], row["attachments"], row["unsubscribe"])
        }
        guard let (text, html, images, attachments, list) = found.flatMap({ $0 }) else { return nil }
        guard let decodedImages = try? JSONDecoder().decode([String: String].self, from: images),
              let decodedAttachments = try? JSONDecoder().decode([AttachmentInfo].self, from: attachments) else { return nil }
        let unsubscribe = list.flatMap { try? JSONDecoder().decode(ListUnsubscribe.self, from: $0) }
        return MessageBody(text: text, html: html, inlineImages: decodedImages, attachments: decodedAttachments, unsubscribe: unsubscribe)
    }

    func keepBody(_ inlet: Inlet.ID, messageID: String, _ body: MessageBody) {
        guard body.text != nil || body.html != nil,
              let images = try? JSONEncoder().encode(body.inlineImages),
              let attachments = try? JSONEncoder().encode(body.attachments) else { return }
        let list = body.unsubscribe.flatMap { try? JSONEncoder().encode($0) }
        try? database.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO mail_body (inlet, id, text, html, images, attachments, unsubscribe) VALUES (?, ?, ?, ?, ?, ?, ?)",
                           arguments: [inlet, messageID, body.text, body.html, images, attachments, list])
        }
    }

    nonisolated static func dropOrphanBodies(_ db: Database, inlet: Inlet.ID, ids: [String]? = nil) throws {
        let orphan = "inlet = ? AND NOT EXISTS (SELECT 1 FROM mail_message WHERE mail_message.inlet = mail_body.inlet AND mail_message.id = mail_body.id)"
        guard let ids else {
            try db.execute(sql: "DELETE FROM mail_body WHERE " + orphan, arguments: [inlet])
            return
        }
        for chunk in MirrorEngine.chunks(ids, size: MirrorEngine.dropSize) {
            let marks = Array(repeating: "?", count: chunk.count).joined(separator: ",")
            try db.execute(sql: "DELETE FROM mail_body WHERE id IN (\(marks)) AND " + orphan,
                           arguments: StatementArguments(chunk + [inlet]))
        }
    }
}
