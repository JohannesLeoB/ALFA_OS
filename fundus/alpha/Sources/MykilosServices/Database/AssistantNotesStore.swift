import Foundation
import GRDB
import MykilosKit

struct AssistantNoteRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "assistantNotes" }
    var id: String
    var body: String
    var projectID: String?
    var color: String?
    var createdAt: Double
    var updatedAt: Double

    var userID: String?

    init(from note: AssistantNote, userID: String?) {
        id = note.id
        body = note.body
        projectID = note.projectID
        color = note.color
        createdAt = note.createdAt.timeIntervalSince1970
        updatedAt = note.updatedAt.timeIntervalSince1970
        self.userID = userID
    }

    var toDomain: AssistantNote {
        AssistantNote(id: id, body: body, projectID: projectID, color: color,
                      createdAt: Date(timeIntervalSince1970: createdAt),
                      updatedAt: Date(timeIntervalSince1970: updatedAt))
    }
}

public actor AssistantNotesStore {
    private let db: GRDBDatabase

    private let userID: String?

    public init(db: GRDBDatabase, userID: String? = CurrentUserContext.current) {
        self.db = db
        self.userID = userID
    }

    public func all() throws -> [AssistantNote] {
        let uid = userID
        return try db.read { conn in
            try AssistantNoteRecord
                .filter(Column("userID") == uid)
                .order(Column("updatedAt").desc)
                .fetchAll(conn)
        }.map(\.toDomain)
    }

    public func scoped(to projectID: String?) throws -> [AssistantNote] {
        let notes = try all()
        guard let projectID, projectID.isEmpty == false else { return notes }
        return notes.filter { $0.projectID == projectID || $0.projectID == nil }
    }

    @discardableResult
    public func create(_ body: String, projectID: String? = nil, now: Date = Date()) throws -> AssistantNote {
        let note = AssistantNote(body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                                 projectID: projectID, createdAt: now, updatedAt: now)
        let record = AssistantNoteRecord(from: note, userID: userID)
        try db.write { conn in try record.insert(conn) }
        return note
    }

    @discardableResult
    public func update(matching query: String, newBody: String, scopedTo projectID: String? = nil, now: Date = Date()) throws -> AssistantNote? {
        guard var note = try find(matching: query, scopedTo: projectID) else { return nil }
        note.body = newBody.trimmingCharacters(in: .whitespacesAndNewlines)
        note.updatedAt = now
        let record = AssistantNoteRecord(from: note, userID: userID)
        try db.write { conn in try record.update(conn) }
        return note
    }

    @discardableResult
    public func delete(matching query: String, scopedTo projectID: String? = nil) throws -> AssistantNote? {
        guard let note = try find(matching: query, scopedTo: projectID) else { return nil }
        _ = try db.write { conn in try AssistantNoteRecord.deleteOne(conn, key: note.id) }
        return note
    }

    @discardableResult
    public func update(id: String, body: String, color: String?, now: Date = Date()) throws -> AssistantNote? {
        guard var note = try all().first(where: { $0.id == id }) else { return nil }
        note.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        note.color = color
        note.updatedAt = now
        let record = AssistantNoteRecord(from: note, userID: userID)
        try db.write { conn in try record.update(conn) }
        return note
    }

    public func find(matching query: String, scopedTo projectID: String? = nil) throws -> AssistantNote? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.isEmpty == false else { return nil }
        let notes = projectID == nil ? try all() : try scoped(to: projectID)
        if let exact = notes.first(where: { $0.id.lowercased() == q }) { return exact }
        if let prefix = notes.first(where: { $0.id.lowercased().hasPrefix(q) }) { return prefix }
        return notes.first(where: { $0.body.lowercased().contains(q) })
    }
}
