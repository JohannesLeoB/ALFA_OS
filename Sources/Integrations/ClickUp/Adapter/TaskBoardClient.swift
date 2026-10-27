import Assistant
import Foundation

public struct TaskBoardClient: TaskBoardPort {
    private let read: any ReadPort
    private let write: any WritePort

    public init(read: any ReadPort, write: any WritePort) {
        self.read = read
        self.write = write
    }

    public func openTasks(listID: String) async throws -> [TaskItem] {
        try await translated {
            try await read.tasks(listID: listID).map {
                TaskItem(id: $0.id, name: $0.name, status: $0.status, isUrgent: $0.isUrgent, dueDate: $0.dueDate,
                         assignee: $0.assignee)
            }
        }
    }

    public func members(listID: String) async throws -> [TaskMember] {
        try await translated {
            try await read.listMembers(listID: listID).map { TaskMember(id: $0.id, username: $0.username) }
        }
    }

    @discardableResult
    public func apply(_ draft: ClickUpChangeDraft) async throws -> String {
        try await translated {
            switch draft.intent {
            case .create:
                let id = try await write.createTask(listID: draft.listID, name: draft.taskName, content: nil)
                if let due = draft.dueDate { try await write.updateTask(taskID: id, name: nil, dueDate: due, priority: nil) }
                return id
            case .status:
                let id = try Self.taskID(draft)
                try await write.setStatus(taskID: id, status: draft.status ?? "")
                return id
            case .dueDate:
                let id = try Self.taskID(draft)
                try await write.updateTask(taskID: id, name: nil, dueDate: draft.dueDate, priority: nil)
                return id
            case .assign:
                let id = try Self.taskID(draft)
                try await write.assign(taskID: id, memberID: draft.memberID ?? "")
                return id
            }
        }
    }

    private static func taskID(_ draft: ClickUpChangeDraft) throws -> String {
        guard let id = draft.taskID, id.isEmpty == false else { throw ClickUpFailure.invalidResponse }
        return id
    }

    private func translated<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch ClickUpFailure.notConnected {
            throw PortFailure.notConnected
        } catch let failure as ClickUpFailure {
            throw PortFailure.failed(failure.detail)
        }
    }
}
