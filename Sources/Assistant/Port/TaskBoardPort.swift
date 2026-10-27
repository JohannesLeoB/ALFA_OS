public protocol TaskBoardPort: Sendable {
    func openTasks(listID: String) async throws -> [TaskItem]
    func members(listID: String) async throws -> [TaskMember]
}
