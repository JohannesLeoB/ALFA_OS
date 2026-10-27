import Hub

public struct ConversationContext: Sendable {
    var focusedProjectID: String?
    var focusedDriveFolderID: String?
    var focusedTaskListID: String?
    var signals: [Signal]
    var projects: [ProjectEntry]
    var profile: UserProfile?
    var actorUserID: String

    public init(focusedProjectID: String? = nil, focusedDriveFolderID: String? = nil, focusedTaskListID: String? = nil,
                signals: [Signal] = [], projects: [ProjectEntry] = [], profile: UserProfile? = nil,
                actorUserID: String = "assistant") {
        self.focusedProjectID = focusedProjectID
        self.focusedDriveFolderID = focusedDriveFolderID
        self.focusedTaskListID = focusedTaskListID
        self.signals = signals
        self.projects = projects
        self.profile = profile
        self.actorUserID = actorUserID
    }

    var scope: ToolScope {
        ToolScope(projectID: focusedProjectID, driveFolderID: focusedDriveFolderID, taskListID: focusedTaskListID)
    }
}
