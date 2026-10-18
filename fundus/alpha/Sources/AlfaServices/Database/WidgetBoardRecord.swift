import Foundation
import GRDB
import AlfaKit

struct WidgetInstanceRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "widgetInstances" }

    var id: String
    var boardID: String
    var kind: String
    var size: String
    var position: Int
    var isVisible: Bool
    var isPinned: Bool

    init(from instance: WidgetInstance, boardID: String) {
        self.id        = instance.id.uuidString
        self.boardID   = boardID
        self.kind      = instance.kind.rawValue
        self.size      = instance.size.rawValue
        self.position  = instance.position
        self.isVisible = instance.isVisible
        self.isPinned  = instance.isPinned
    }

    var toDomain: WidgetInstance {
        WidgetInstance(
            id: UUID(uuidString: id) ?? UUID(),
            kind: WidgetKind(rawValue: kind) ?? .notes,
            size: WidgetSize(rawValue: size) ?? .medium,
            position: position,
            isVisible: isVisible,
            isPinned: isPinned
        )
    }
}

struct NoteRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "notes" }

    var id: String
    var boardID: String
    var body: String
    var updatedAt: Double

    init(id: UUID = UUID(), boardID: String, body: String, updatedAt: Date = Date()) {
        self.id        = id.uuidString
        self.boardID   = boardID
        self.body      = body
        self.updatedAt = updatedAt.timeIntervalSince1970
    }

    var updatedAtDate: Date { Date(timeIntervalSince1970: updatedAt) }
}

struct AuditRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case id, timestamp, actorUserID, projectID, action, summary, source = "quelle", idempotenzKey }

    static var databaseTableName: String { "auditEntries" }

    var id: String
    var timestamp: Double
    var actorUserID: String
    var projectID: String
    var action: String
    var summary: String

    var source: String?
    var idempotenzKey: String?

    init(from entry: AuditEntry) {
        self.id          = entry.id.uuidString
        self.timestamp   = entry.timestamp.timeIntervalSince1970
        self.actorUserID = entry.actorUserID
        self.projectID   = entry.projectID
        self.action      = entry.action.rawValue
        self.summary     = entry.summary
        self.source        = entry.source
        self.idempotenzKey = entry.idempotenzKey
    }

    var toDomain: AuditEntry? {
        guard let id = UUID(uuidString: id),
              let action = AuditEntry.Action(rawValue: action) else { return nil }
        return AuditEntry(
            id: id,
            timestamp: Date(timeIntervalSince1970: timestamp),
            actorUserID: actorUserID,
            projectID: projectID,
            action: action,
            summary: summary,
            source: source,
            idempotenzKey: idempotenzKey
        )
    }
}
