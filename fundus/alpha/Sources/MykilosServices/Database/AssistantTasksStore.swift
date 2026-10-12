import Foundation
import GRDB
import MykilosKit

struct AssistantTaskRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "assistantTasks" }
    var id: String
    var title: String
    var done: Bool
    var dueDate: Double?
    var projectID: String?
    var createdAt: Double
    var updatedAt: Double

    var userID: String?

    var alarmAktiv: Bool

    init(from task: AssistantTask, userID: String?) {
        id = task.id
        title = task.title
        done = task.done
        dueDate = task.dueDate?.timeIntervalSince1970
        projectID = task.projectID
        createdAt = task.createdAt.timeIntervalSince1970
        updatedAt = task.updatedAt.timeIntervalSince1970
        self.userID = userID
        alarmAktiv = task.alarmAktiv
    }

    var toDomain: AssistantTask {
        AssistantTask(id: id, title: title, done: done,
                      dueDate: dueDate.map { Date(timeIntervalSince1970: $0) },
                      projectID: projectID, alarmAktiv: alarmAktiv,
                      createdAt: Date(timeIntervalSince1970: createdAt),
                      updatedAt: Date(timeIntervalSince1970: updatedAt))
    }
}

public actor AssistantTasksStore {
    private let db: GRDBDatabase

    private let userID: String?

    public init(db: GRDBDatabase, userID: String? = CurrentUserContext.current) {
        self.db = db
        self.userID = userID
    }

    public func all() throws -> [AssistantTask] {
        let uid = userID
        let tasks = try db.read { conn in
            try AssistantTaskRecord
                .filter(Column("userID") == uid)
                .order(Column("updatedAt").desc)
                .fetchAll(conn)
        }.map(\.toDomain)
        return tasks.sorted { lhs, rhs in
            if lhs.done != rhs.done { return !lhs.done }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?): return l < r
            case (nil, _?):    return false
            case (_?, nil):    return true
            case (nil, nil):   return lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    public func open() throws -> [AssistantTask] {
        try all().filter { !$0.done }
    }

    public func scoped(to projectID: String?) throws -> [AssistantTask] {
        let tasks = try all()
        guard let projectID, projectID.isEmpty == false else { return tasks }
        return tasks.filter { $0.projectID == projectID || $0.projectID == nil }
    }

    @discardableResult
    public func create(
        _ title: String, dueDate: Date? = nil, projectID: String? = nil,
        alarmAktiv: Bool = false, now: Date = Date()
    ) throws -> AssistantTask {
        let task = AssistantTask(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                 dueDate: dueDate, projectID: projectID, alarmAktiv: alarmAktiv,
                                 createdAt: now, updatedAt: now)
        let record = AssistantTaskRecord(from: task, userID: userID)
        try db.write { conn in try record.insert(conn) }
        return task
    }

    @discardableResult
    public func update(
        id: String, title: String, dueDate: Date?, alarmAktiv: Bool, now: Date = Date()
    ) throws -> AssistantTask? {
        guard var task = try all().first(where: { $0.id == id }) else { return nil }
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.dueDate = dueDate
        task.alarmAktiv = alarmAktiv
        task.updatedAt = now
        let record = AssistantTaskRecord(from: task, userID: userID)
        try db.write { conn in try record.update(conn) }
        return task
    }

    @discardableResult
    public func setDone(id: String, done: Bool, now: Date = Date()) throws -> AssistantTask? {
        guard var task = try all().first(where: { $0.id == id }) else { return nil }
        task.done = done
        task.updatedAt = now
        let record = AssistantTaskRecord(from: task, userID: userID)
        try db.write { conn in try record.update(conn) }
        return task
    }

    @discardableResult
    public func delete(id: String) throws -> AssistantTask? {
        guard let task = try all().first(where: { $0.id == id }) else { return nil }
        _ = try db.write { conn in try AssistantTaskRecord.deleteOne(conn, key: id) }
        return task
    }

    @discardableResult
    public func setDone(matching query: String, done: Bool = true, scopedTo projectID: String? = nil, now: Date = Date()) throws -> AssistantTask? {
        guard var task = try find(matching: query, scopedTo: projectID) else { return nil }
        task.done = done
        task.updatedAt = now
        let record = AssistantTaskRecord(from: task, userID: userID)
        try db.write { conn in try record.update(conn) }
        return task
    }

    @discardableResult
    public func delete(matching query: String, scopedTo projectID: String? = nil) throws -> AssistantTask? {
        guard let task = try find(matching: query, scopedTo: projectID) else { return nil }
        _ = try db.write { conn in try AssistantTaskRecord.deleteOne(conn, key: task.id) }
        return task
    }

    public func find(matching query: String, scopedTo projectID: String? = nil) throws -> AssistantTask? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.isEmpty == false else { return nil }
        let tasks = projectID == nil ? try all() : try scoped(to: projectID)
        if let exact = tasks.first(where: { $0.id.lowercased() == q }) { return exact }
        if let prefix = tasks.first(where: { $0.id.lowercased().hasPrefix(q) }) { return prefix }
        return tasks.first(where: { $0.title.lowercased().contains(q) })
    }
}
