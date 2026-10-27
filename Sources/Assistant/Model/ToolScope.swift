public struct ToolScope: Sendable, Equatable {
    var projectID: String?
    var driveFolderID: String?
    var taskListID: String?

    init(projectID: String? = nil, driveFolderID: String? = nil, taskListID: String? = nil) {
        self.projectID = Self.clean(projectID)
        self.driveFolderID = Self.clean(driveFolderID)
        self.taskListID = Self.clean(taskListID)
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum FocusNeed: Sendable, Equatable {
    case none
    case driveFolder
    case taskList
}
