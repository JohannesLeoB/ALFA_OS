import Foundation

public protocol WritePort: Sendable {
    func createTask(listID: String, name: String, content: String?) async throws -> String
    func setStatus(taskID: String, status: String) async throws
    func updateTask(taskID: String, name: String?, dueDate: Date?, priority: Priority?) async throws
    func assign(taskID: String, memberID: String) async throws
}
