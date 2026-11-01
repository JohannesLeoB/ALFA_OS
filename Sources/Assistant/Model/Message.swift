import Calculation
import Foundation
import Hub

public enum MessageRole: String, Codable, Sendable, Equatable {
    case user
    case assistant
}

public enum TurnStatus: Codable, Sendable, Equatable {
    case complete
    case streaming
    case failed(String)
}

public enum ConversationScope: Codable, Sendable, Equatable, Hashable {
    case home
    case project(String)

    var rawKey: String {
        switch self {
        case .home: "home"
        case .project(let number): "project:\(number)"
        }
    }

    init?(rawKey: String) {
        if rawKey == "home" {
            self = .home
        } else if rawKey.hasPrefix("project:") {
            self = .project(String(rawKey.dropFirst("project:".count)))
        } else {
            return nil
        }
    }
}

public struct AttachmentRef: Codable, Sendable, Equatable {
    public var fileName: String
    public var mimeType: String
    var byteCount: Int
    var relativePath: String
    var sha256: String

    init(fileName: String, mimeType: String, byteCount: Int, relativePath: String, sha256: String) {
        self.fileName = fileName
        self.mimeType = mimeType
        self.byteCount = byteCount
        self.relativePath = relativePath
        self.sha256 = sha256
    }
}

public enum ContentBlock: Codable, Sendable, Equatable {
    case text(String)
    case toolUse(id: String, name: String, inputJSON: Data)
    case toolResult(toolUseID: String, summary: String, isError: Bool)
    case toolActivity(label: String, isError: Bool)
    case calendarLink(url: String)
    case contactDraft(ContactDraft)
    case mailDraft(MailDraft)
    case driveFiles([DriveLink])
    case estimate(estimateID: String, projectID: String, minNet: Double, maxNet: Double, midNet: Double,
                  confidence: Double, evidenceCount: Int)
    case estimateBreakdown(estimateID: String, lines: [EstimateBreakdownLine], excludes: [Notice])
    case airtableContactDraft(AirtableContactDraft)
    case taskChangeDraft(ClickUpChangeDraft)
    case appointmentDraft(AppointmentDraft)
    case cartDraft(CartDraft)
    case fileDraft(FileDraft)
    case image(AttachmentRef)
    case document(AttachmentRef)
    case unreadable
}

public struct Message: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    var role: MessageRole
    var blocks: [ContentBlock]
    public var status: TurnStatus
    var createdAt: Date

    init(id: UUID = UUID(), role: MessageRole, blocks: [ContentBlock], status: TurnStatus = .complete,
                createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.blocks = blocks
        self.status = status
        self.createdAt = createdAt
    }

    static func text(_ text: String, role: MessageRole, status: TurnStatus = .complete) -> Message {
        Message(role: role, blocks: [.text(text)], status: status)
    }

    var text: String {
        blocks.compactMap { if case .text(let value) = $0 { value } else { nil } }.joined(separator: "\n")
    }
}

public struct ChatTurn: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case user
        case assistant
        case streaming
        case failed
    }

    public let id: UUID
    public let kind: Kind
    public let blocks: [TurnBlock]
}

public enum TurnBlock: Equatable, Sendable {
    case activity(label: String, failed: Bool)
    case text(String)
    case draft(DraftSummary)
    case estimate(minNet: Double, maxNet: Double)
    case breakdown(lines: Int)
    case file(String)
    case unreadable

    var isFile: Bool {
        if case .file = self { true } else { false }
    }
}

public struct DraftSummary: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case mail
        case contact
        case task
        case appointment
        case cart
        case file
        case calendar
    }

    public let kind: Kind
    public let title: String
    public let line: String?

    init(kind: Kind, title: String, line: String? = nil) {
        self.kind = kind
        self.title = title
        self.line = line.flatMap { $0.isEmpty ? nil : $0 }
    }
}

public struct MemorySummary: Sendable, Equatable {
    let scopeKey: String
    let summaryText: String
    let coveredThroughMessageID: String
    let updatedAt: Date

    init(scopeKey: String, summaryText: String, coveredThroughMessageID: String, updatedAt: Date) {
        self.scopeKey = scopeKey
        self.summaryText = summaryText
        self.coveredThroughMessageID = coveredThroughMessageID
        self.updatedAt = updatedAt
    }
}

struct ConversationContext: Sendable {
    var focusedProjectID: String?
    var focusedDriveFolderID: String?
    var focusedTaskListID: String?
    var signals: [Signal]
    var projects: [ProjectEntry]
    var profile: UserProfile?
    var actorUserID: String

    init(focusedProjectID: String? = nil, focusedDriveFolderID: String? = nil, focusedTaskListID: String? = nil,
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

enum Signal: Sendable, Equatable {
    case projectFocused(projectID: String)
    case driveFileAdded(projectID: String, fileName: String)
    case offerDetected(projectID: String, label: String)
    case drawingDetected(projectID: String, label: String)
    case reviewSuggested(projectID: String, label: String)
    case budgetThresholdCrossed(projectID: String, ratio: Double)
    case deadlineNear(projectID: String, days: Int)
    case taskDueSoon(projectID: String, taskName: String, days: Int)

    var projectNumber: String {
        switch self {
        case .projectFocused(let id),
             .driveFileAdded(let id, _),
             .offerDetected(let id, _),
             .drawingDetected(let id, _),
             .reviewSuggested(let id, _),
             .budgetThresholdCrossed(let id, _),
             .deadlineNear(let id, _),
             .taskDueSoon(let id, _, _):
            id
        }
    }
}

struct ProjectEntry: Sendable, Equatable {
    let projectNumber: String
    let title: String
    let customerName: String?
    let driveFolderID: String?
    let phase: String?
    let budget: Double?

    init(projectNumber: String, title: String, customerName: String? = nil, driveFolderID: String? = nil,
         phase: String? = nil, budget: Double? = nil) {
        self.projectNumber = projectNumber
        self.title = title
        self.customerName = customerName
        self.driveFolderID = driveFolderID
        self.phase = phase
        self.budget = budget
    }
}
