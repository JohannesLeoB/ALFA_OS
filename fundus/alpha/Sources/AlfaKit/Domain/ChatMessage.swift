import Foundation

public enum ChatRole: String, Codable, Sendable, Equatable {
    case user
    case assistant
}

public enum ChatTurnStatus: Codable, Sendable, Equatable {
    case complete
    case streaming
    case failed(String)
}

public enum ChatScope: Codable, Sendable, Equatable, Hashable {
    case home
    case project(String)

    public var rawKey: String {
        switch self {
        case .home:               "home"
        case .project(let number): "project:\(number)"
        }
    }

    public init?(rawKey: String) {
        if rawKey == "home" {
            self = .home
        } else if rawKey.hasPrefix("project:") {
            self = .project(String(rawKey.dropFirst("project:".count)))
        } else {
            return nil
        }
    }
}

public struct ChatAttachmentRef: Codable, Sendable, Equatable {
    public var fileName: String
    public var mimeType: String
    public var byteCount: Int
    public var relativePath: String
    public var sha256: String

    public init(fileName: String, mimeType: String, byteCount: Int, relativePath: String, sha256: String) {
        self.fileName = fileName
        self.mimeType = mimeType
        self.byteCount = byteCount
        self.relativePath = relativePath
        self.sha256 = sha256
    }
}

public enum ChatContentBlock: Codable, Sendable, Equatable {
    case text(String)
    case toolUse(id: String, name: String, inputJSON: Data)
    case toolResult(toolUseID: String, summary: String, isError: Bool)

    case toolActivity(label: String, isError: Bool)

    case calendarAction(url: String, label: String)

    case contactAction(draft: ContactDraft)

    case draftAction(draft: EmailDraft)

    case driveFiles(label: String, files: [DriveFileRef])

    case kalkulationsSchaetzung(schaetzungsID: String, projektID: String, minNetto: Double, maxNetto: Double, mitteNetto: Double, confidence: Double, evidenceCount: Int)

    case estimateBreakdown(schaetzungsID: String, lines: [EstimateBreakdownLine], excludes: [String])

    case airtableContactAction(draft: AirtableContactDraft)
    case clickUpAction(draft: ClickUpChangeDraft)
    case terminAction(draft: TerminDraft)
    case warenkorbAction(draft: WarenkorbDraft)
    case dateiAction(draft: DateiDraft)
    case image(ChatAttachmentRef)
    case document(ChatAttachmentRef)
}

public struct ChatMessage: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var role: ChatRole
    public var blocks: [ChatContentBlock]
    public var status: ChatTurnStatus
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        blocks: [ChatContentBlock],
        status: ChatTurnStatus = .complete,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.blocks = blocks
        self.status = status
        self.createdAt = createdAt
    }

    public static func text(_ text: String, role: ChatRole, status: ChatTurnStatus = .complete) -> ChatMessage {
        ChatMessage(role: role, blocks: [.text(text)], status: status)
    }

    public var text: String {
        blocks.compactMap { if case let .text(value) = $0 { return value } else { return nil } }
            .joined(separator: "\n")
    }
}
