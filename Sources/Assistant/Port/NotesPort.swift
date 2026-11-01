import Foundation

public protocol NotesPort: Sendable {
    func all() async throws -> [Note]
    func scoped(to projectID: String?) async throws -> [Note]
    @discardableResult
    func create(_ body: String, projectID: String?, now: Date) async throws -> Note
    @discardableResult
    func update(matching query: String, newBody: String, scopedTo projectID: String?, now: Date) async throws -> Note?
    @discardableResult
    func delete(matching query: String, scopedTo projectID: String?) async throws -> Note?
}

extension NotesPort {
    @discardableResult
    func create(_ body: String, projectID: String?) async throws -> Note {
        try await create(body, projectID: projectID, now: Date())
    }

    @discardableResult
    func update(matching query: String, newBody: String, scopedTo projectID: String?) async throws -> Note? {
        try await update(matching: query, newBody: newBody, scopedTo: projectID, now: Date())
    }
}

public protocol TodosPort: Sendable {
    func all() async throws -> [Todo]
    func scoped(to projectID: String?) async throws -> [Todo]
    @discardableResult
    func create(_ title: String, dueDate: Date?, projectID: String?, alarmActive: Bool, now: Date) async throws -> Todo
    @discardableResult
    func setDone(matching query: String, done: Bool, scopedTo projectID: String?, now: Date) async throws -> Todo?
    @discardableResult
    func delete(matching query: String, scopedTo projectID: String?) async throws -> Todo?
}

extension TodosPort {
    @discardableResult
    func create(_ title: String, dueDate: Date?, projectID: String?, alarmActive: Bool) async throws -> Todo {
        try await create(title, dueDate: dueDate, projectID: projectID, alarmActive: alarmActive, now: Date())
    }

    @discardableResult
    func setDone(matching query: String, done: Bool, scopedTo projectID: String?) async throws -> Todo? {
        try await setDone(matching: query, done: done, scopedTo: projectID, now: Date())
    }
}

public protocol JournalPort: Sendable {
    @discardableResult
    func append(_ entry: JournalEntry) async throws -> JournalEntry
}
