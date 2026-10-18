import Foundation
import GRDB
import AlfaKit

struct MailMessageRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static var databaseTableName: String { "mailMessage" }
    var id: String
    var account: String
    var threadId: String
    var subject: String
    var fromName: String
    var fromRaw: String
    var toRaw: String
    var ccRaw: String
    var snippet: String
    var receivedAt: Double?
    var labels: String
    var hasAttachments: Bool
    var attachments: String
    var messageIdHeader: String
    var historyId: String
    var bodyText: String?
    var bodyHTML: String?
    var inlineImages: String?
    var fetchedAt: Double

    private struct Att: Codable { var id: String; var name: String; var mime: String; var size: Int }

    init(_ m: GoogleGmailMessage, account: String, jetzt: Date = Date()) {
        id = m.id
        self.account = account
        threadId = m.threadID
        subject = m.subject
        fromName = m.from
        fromRaw = m.fromRaw
        toRaw = m.toRaw
        ccRaw = m.ccRaw
        snippet = m.snippet
        receivedAt = m.receivedAt?.timeIntervalSince1970
        labels = Self.json(m.labels)
        hasAttachments = m.attachments.isEmpty == false
        attachments = Self.json(m.attachments.map { Att(id: $0.attachmentID, name: $0.filename, mime: $0.mimeType, size: $0.sizeBytes) })
        messageIdHeader = m.messageIDHeader
        historyId = m.historyID
        fetchedAt = jetzt.timeIntervalSince1970
    }

    var message: GoogleGmailMessage {
        let atts = (Self.decode([Att].self, attachments) ?? []).map {
            GmailAttachment(attachmentID: $0.id, filename: $0.name, mimeType: $0.mime, sizeBytes: $0.size)
        }
        return GoogleGmailMessage(
            id: id, threadID: threadId, subject: subject, from: fromName, fromRaw: fromRaw, toRaw: toRaw, ccRaw: ccRaw,
            snippet: snippet, receivedAt: receivedAt.map { Date(timeIntervalSince1970: $0) },
            labels: Self.decode([String].self, labels) ?? [], attachments: atts,
            messageIDHeader: messageIdHeader, historyID: historyId)
    }

    var body: GmailMailBody? {
        guard bodyText != nil || bodyHTML != nil else { return nil }
        return GmailMailBody(text: bodyText, html: bodyHTML,
                             inlineImages: inlineImages.flatMap { Self.decode([String: String].self, $0) } ?? [:])
    }

    static func json<T: Encodable>(_ v: T) -> String {
        (try? JSONEncoder().encode(v)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    static func decode<T: Decodable>(_ t: T.Type, _ s: String) -> T? {
        s.data(using: .utf8).flatMap { try? JSONDecoder().decode(t, from: $0) }
    }
}

struct MailSyncRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static var databaseTableName: String { "mailSync" }
    var account: String
    var historyId: String
    var updatedAt: Double
}

public enum MailLocalFilter: Sendable, Equatable {
    case label(String)
    case archive
    case all
}

public final class MailStore: Sendable {
    private let db: GRDBDatabase

    public init(db: GRDBDatabase) { self.db = db }

    public func upsert(_ messages: [GoogleGmailMessage], account: String) {
        guard messages.isEmpty == false else { return }
        let records = messages.map { MailMessageRecord($0, account: account) }
        try? db.write { db in
            for r in records {
                if let alt = try MailMessageRecord.fetchOne(db, key: r.id) {
                    var neu = r
                    neu.bodyText = alt.bodyText
                    neu.bodyHTML = alt.bodyHTML
                    neu.inlineImages = alt.inlineImages
                    try neu.update(db)
                } else {
                    try r.insert(db)
                }
            }
        }
    }

    public func setLabels(_ labels: [String], for id: String) {
        let json = MailMessageRecord.json(labels)
        try? db.write { db in
            try db.execute(sql: "UPDATE mailMessage SET labels = ? WHERE id = ?", arguments: [json, id])
        }
    }

    public func delete(ids: [String]) {
        guard ids.isEmpty == false else { return }
        try? db.write { db in
            for id in ids { _ = try MailMessageRecord.deleteOne(db, key: id) }
        }
    }

    public func saveBody(_ body: GmailMailBody, for id: String) {
        let inline = MailMessageRecord.json(body.inlineImages)
        try? db.write { db in
            try db.execute(sql: "UPDATE mailMessage SET bodyText = ?, bodyHTML = ?, inlineImages = ? WHERE id = ?",
                           arguments: [body.text, body.html, inline, id])
        }
    }

    public func body(for id: String) -> GmailMailBody? {
        (try? db.read { try MailMessageRecord.fetchOne($0, key: id) })?.flatMap { $0.body } ?? nil
    }

    public func messages(account: String, filter: MailLocalFilter, limit: Int = 200) -> [GoogleGmailMessage] {
        var sql = "SELECT * FROM mailMessage WHERE account = ?"
        var args: [DatabaseValueConvertible?] = [account]
        switch filter {
        case .label(let id):
            sql += " AND labels LIKE ?"
            args.append("%\"\(id)\"%")
        case .archive:
            for l in ["INBOX", "SENT", "DRAFT", "SPAM", "TRASH"] {
                sql += " AND labels NOT LIKE ?"
                args.append("%\"\(l)\"%")
            }
        case .all:
            for l in ["SPAM", "TRASH"] {
                sql += " AND labels NOT LIKE ?"
                args.append("%\"\(l)\"%")
            }
        }
        sql += " ORDER BY receivedAt DESC LIMIT ?"
        args.append(limit)
        let statement = sql
        let arguments = StatementArguments(args)
        let records = (try? db.read { try MailMessageRecord.fetchAll($0, sql: statement, arguments: arguments) }) ?? []
        return records.map(\.message)
    }

    public func search(account: String, text: String, limit: Int = 100) -> [GoogleGmailMessage] {
        guard let pattern = FTS5Pattern(matchingAllPrefixesIn: text) else { return [] }
        let records = (try? db.read { db in
            try MailMessageRecord.fetchAll(db, sql: """
                SELECT mailMessage.* FROM mailMessage
                JOIN mailFTS ON mailFTS.rowid = mailMessage.rowid
                WHERE mailMessage.account = ? AND mailFTS MATCH ?
                ORDER BY mailMessage.receivedAt DESC LIMIT ?
                """, arguments: [account, pattern, limit])
        }) ?? []
        return records.map(\.message)
    }

    public func unreadCount(account: String) -> Int {
        (try? db.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mailMessage WHERE account = ? AND labels LIKE ? AND labels LIKE ?",
                             arguments: [account, "%\"INBOX\"%", "%\"UNREAD\"%"])
        }) ?? 0
    }

    public func historyId(account: String) -> String? {
        let r = try? db.read { try MailSyncRecord.fetchOne($0, key: account) }
        let hid = r?.historyId ?? ""
        return hid.isEmpty ? nil : hid
    }

    public func setHistoryId(_ historyId: String, account: String) {
        let r = MailSyncRecord(account: account, historyId: historyId, updatedAt: Date().timeIntervalSince1970)
        try? db.write { try r.save($0) }
    }

    public func count(account: String) -> Int {
        (try? db.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mailMessage WHERE account = ?", arguments: [account]) }) ?? 0
    }
}
