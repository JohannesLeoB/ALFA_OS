import Foundation

public struct AssistantInsight: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let projectID: String
    public let summary: String
    public let detail: String?
    public let source: InsightSource
    public let priority: InsightPriority
    public let suggestedAction: SuggestedAction?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        projectID: String,
        summary: String,
        detail: String? = nil,
        source: InsightSource,
        priority: InsightPriority = .info,
        suggestedAction: SuggestedAction? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.summary = summary
        self.detail = detail
        self.source = source
        self.priority = priority
        self.suggestedAction = suggestedAction
        self.createdAt = createdAt
    }
}

public enum InsightSource: String, Codable, Sendable {
    case signals
    case calendar
    case drive
    case clockodo
    case mail
    case contacts
    case budget
}

public enum InsightPriority: Int, Codable, Sendable, Comparable {
    case info = 0
    case attention = 1
    case urgent = 2

    public static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct SuggestedAction: Equatable, Sendable {
    public let label: String
    public let auditAction: AuditEntry.Action
    public let auditSummary: String

    public init(label: String, auditAction: AuditEntry.Action, auditSummary: String) {
        self.label = label
        self.auditAction = auditAction
        self.auditSummary = auditSummary
    }
}
