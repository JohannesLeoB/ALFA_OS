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

public actor NoteStore: NotesPort {
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

private struct StoredTodo: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "assistantTasks" }

    var id: String
    var title: String
    var done: Bool
    var dueDate: Double?
    var projectID: String?
    var createdAt: Double
    var updatedAt: Double
    var userID: String?
    var alarmActive: Bool

    init(_ todo: Todo, userID: String?) {
        id = todo.id
        title = todo.title
        done = todo.done
        dueDate = todo.dueDate?.timeIntervalSince1970
        projectID = todo.projectID
        createdAt = todo.createdAt.timeIntervalSince1970
        updatedAt = todo.updatedAt.timeIntervalSince1970
        self.userID = userID
        alarmActive = todo.alarmActive
    }

    var todo: Todo {
        Todo(id: id, title: title, done: done, dueDate: dueDate.map { Date(timeIntervalSince1970: $0) },
             projectID: projectID, alarmActive: alarmActive,
             createdAt: Date(timeIntervalSince1970: createdAt), updatedAt: Date(timeIntervalSince1970: updatedAt))
    }
}

public actor TodoStore: TodosPort {
    private let database: SQLiteStore
    private let userID: String?

    public init(database: SQLiteStore, userID: String?) {
        self.database = database
        self.userID = userID
    }

    public func all() throws -> [Todo] {
        let owner = userID
        let todos = try database.read { db in
            try StoredTodo.filter(Column("userID") == owner).order(Column("updatedAt").desc).fetchAll(db)
        }.map(\.todo)
        return todos.sorted { lhs, rhs in
            if lhs.done != rhs.done { return !lhs.done }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?): return left < right
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    public func scoped(to projectID: String?) throws -> [Todo] {
        try all().scoped(to: projectID, by: \.projectID)
    }

    @discardableResult
    public func create(_ title: String, dueDate: Date? = nil, projectID: String? = nil, alarmActive: Bool = false,
                       now: Date = Date()) throws -> Todo {
        let todo = Todo(title: title.trimmingCharacters(in: .whitespacesAndNewlines), dueDate: dueDate,
                        projectID: projectID, alarmActive: alarmActive, createdAt: now, updatedAt: now)
        let record = StoredTodo(todo, userID: userID)
        try database.write { db in try record.insert(db) }
        return todo
    }

    @discardableResult
    public func setDone(matching query: String, done: Bool = true, scopedTo projectID: String? = nil,
                 now: Date = Date()) throws -> Todo? {
        guard var todo = try find(matching: query, scopedTo: projectID) else { return nil }
        todo.done = done
        todo.updatedAt = now
        let record = StoredTodo(todo, userID: userID)
        try database.write { db in try record.update(db) }
        return todo
    }

    @discardableResult
    public func delete(matching query: String, scopedTo projectID: String? = nil) throws -> Todo? {
        guard let todo = try find(matching: query, scopedTo: projectID) else { return nil }
        let id = todo.id
        _ = try database.write { db in try StoredTodo.deleteOne(db, key: id) }
        return todo
    }

    func find(matching query: String, scopedTo projectID: String? = nil) throws -> Todo? {
        try (projectID == nil ? all() : scoped(to: projectID)).first(matching: query, id: \.id, text: \.title)
    }
}

private struct StoredJournalEntry: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "assistantJournal" }

    var id: String
    var timestamp: Double
    var projectID: String?
    var kind: String
    var text: String

    init(_ entry: JournalEntry) {
        id = entry.id.uuidString
        timestamp = entry.timestamp.timeIntervalSince1970
        projectID = entry.projectID
        kind = entry.kind.rawValue
        text = entry.text
    }

    var entry: JournalEntry? {
        guard let uuid = UUID(uuidString: id), let parsed = JournalEntry.Kind(rawValue: kind) else { return nil }
        return JournalEntry(id: uuid, timestamp: Date(timeIntervalSince1970: timestamp), projectID: projectID,
                            kind: parsed, text: text)
    }
}

public actor JournalStore: JournalPort {
    private let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    public func entries(projectID: String? = nil) throws -> [JournalEntry] {
        try database.read { db in
            var request = StoredJournalEntry.order(Column("timestamp").desc)
            if let projectID { request = request.filter(Column("projectID") == projectID) }
            return try request.fetchAll(db)
        }.compactMap(\.entry)
    }

    @discardableResult
    public func append(_ entry: JournalEntry) throws -> JournalEntry {
        let record = StoredJournalEntry(entry)
        try database.write { db in try record.insert(db) }
        return entry
    }
}
