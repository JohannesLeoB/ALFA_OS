import Foundation
import GRDB
import Storage

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

public actor TodoStore {
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
    func setDone(matching query: String, done: Bool = true, scopedTo projectID: String? = nil,
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
