import Foundation

public protocol ReadPort: Sendable {
    func tasks(listID: String, includeClosed: Bool) async throws -> [ClickUpTask]
    func listMembers(listID: String) async throws -> [Member]
}

public extension ReadPort {
    func tasks(listID: String) async throws -> [ClickUpTask] {
        try await tasks(listID: listID, includeClosed: false)
    }
}

public protocol WritePort: Sendable {
    func createTask(listID: String, name: String, content: String?) async throws -> String
    func setStatus(taskID: String, status: String) async throws
    func updateTask(taskID: String, name: String?, dueDate: Date?, priority: Priority?) async throws
    func assign(taskID: String, memberID: String) async throws
}

public protocol CredentialsPort: Sendable {
    func load() throws -> Credentials?
}
