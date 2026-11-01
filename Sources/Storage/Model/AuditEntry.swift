import Foundation

public enum AuditAction: String, Sendable {
    case estimateAdjusted
    case calibrationPromoted
}

public struct AuditEntry: Sendable {
    let id: UUID
    let timestamp: Date
    let actorUserID: String
    public let projectID: String
    let action: AuditAction
    public let summary: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), actorUserID: String,
                projectID: String, action: AuditAction, summary: String) {
        self.id = id
        self.timestamp = timestamp
        self.actorUserID = actorUserID
        self.projectID = projectID
        self.action = action
        self.summary = summary
    }
}

public enum IntegrationAction: String, Sendable {
    case success = "SUCCESS"
    case error = "ERROR"
}

public struct IntegrationEntry: Sendable {
    public let integrationID: String
    public let actorUserID: String
    public let action: IntegrationAction
    public let errorMessage: String?
    public let summary: String
}
