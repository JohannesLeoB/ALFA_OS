import Foundation
import GRDB
import Storage

private struct StoredNote: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "assistantNotes" }

    var id: String
    var body: String
    var projectID: String?
    var color: String?
    var createdAt: Double
    var updatedAt: Double
    var userID: String?

    init(_ note: Note, userID: String?) {
        id = note.id
        body = note.body
        projectID = note.projectID
        color = note.color
        createdAt = note.createdAt.timeIntervalSince1970
        updatedAt = note.updatedAt.timeIntervalSince1970
        self.userID = userID
    }

    var note: Note {
        Note(id: id, body: body, projectID: projectID, color: color,
             createdAt: Date(timeIntervalSince1970: createdAt), updatedAt: Date(timeIntervalSince1970: updatedAt))
    }
}

public actor NoteStore {
    private let database: SQLiteStore
    private let userID: String?

    public init(database: SQLiteStore, userID: String?) {
        self.database = database
        self.userID = userID
    }

    public func all() throws -> [Note] {
        let owner = userID
        return try database.read { db in
            try StoredNote.filter(Column("userID") == owner).order(Column("updatedAt").desc).fetchAll(db)
        }.map(\.note)
    }

    public func scoped(to projectID: String?) throws -> [Note] {
        try all().scoped(to: projectID, by: \.projectID)
    }

    @discardableResult
    public func create(_ body: String, projectID: String? = nil, now: Date = Date()) throws -> Note {
        let note = Note(body: body.trimmingCharacters(in: .whitespacesAndNewlines), projectID: projectID,
                        createdAt: now, updatedAt: now)
        let record = StoredNote(note, userID: userID)
        try database.write { db in try record.insert(db) }
        return note
    }

    @discardableResult
    public func update(matching query: String, newBody: String, scopedTo projectID: String? = nil,
                       now: Date = Date()) throws -> Note? {
        guard var note = try find(matching: query, scopedTo: projectID) else { return nil }
        note.body = newBody.trimmingCharacters(in: .whitespacesAndNewlines)
        note.updatedAt = now
        let record = StoredNote(note, userID: userID)
        try database.write { db in try record.update(db) }
        return note
    }

    @discardableResult
    public func delete(matching query: String, scopedTo projectID: String? = nil) throws -> Note? {
        guard let note = try find(matching: query, scopedTo: projectID) else { return nil }
        let id = note.id
        _ = try database.write { db in try StoredNote.deleteOne(db, key: id) }
        return note
    }

    func find(matching query: String, scopedTo projectID: String? = nil) throws -> Note? {
        try (projectID == nil ? all() : scoped(to: projectID)).first(matching: query, id: \.id, text: \.body)
    }
}

extension Array {
    func scoped(to projectID: String?, by key: KeyPath<Element, String?>) -> [Element] {
        guard let projectID, projectID.isEmpty == false else { return self }
        return filter { $0[keyPath: key] == projectID || $0[keyPath: key] == nil }
    }

    func first(matching query: String, id: KeyPath<Element, String>, text: KeyPath<Element, String>) -> Element? {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.isEmpty == false else { return nil }
        if let exact = first(where: { $0[keyPath: id].lowercased() == needle }) { return exact }
        if let prefix = first(where: { $0[keyPath: id].lowercased().hasPrefix(needle) }) { return prefix }
        return first(where: { $0[keyPath: text].lowercased().contains(needle) })
    }
}
