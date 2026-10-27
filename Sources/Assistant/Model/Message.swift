import Calculation
import Foundation

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

    public init(fileName: String, mimeType: String, byteCount: Int, relativePath: String, sha256: String) {
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
    public var role: MessageRole
    var blocks: [ContentBlock]
    public var status: TurnStatus
    public var createdAt: Date

    public init(id: UUID = UUID(), role: MessageRole, blocks: [ContentBlock], status: TurnStatus = .complete,
                createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.blocks = blocks
        self.status = status
        self.createdAt = createdAt
    }

    public static func text(_ text: String, role: MessageRole, status: TurnStatus = .complete) -> Message {
        Message(role: role, blocks: [.text(text)], status: status)
    }

    public var text: String {
        blocks.compactMap { if case .text(let value) = $0 { value } else { nil } }.joined(separator: "\n")
    }
}
