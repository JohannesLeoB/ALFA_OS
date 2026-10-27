public protocol ReadPort: Sendable {
    func tasks(listID: String, includeClosed: Bool) async throws -> [ClickUpTask]
    func listMembers(listID: String) async throws -> [Member]
}

public extension ReadPort {
    func tasks(listID: String) async throws -> [ClickUpTask] {
        try await tasks(listID: listID, includeClosed: false)
    }
}
