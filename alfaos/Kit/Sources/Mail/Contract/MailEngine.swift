import Foundation
import Hub
import struct AlfaKit.EmailDraft
import enum AlfaServices.MailFlag
import struct AlfaServices.MailFolder
import struct AlfaServices.MailStoredDraft
import struct AlfaServices.MailMessageBody
import struct AlfaServices.MailMessagePage
import struct AlfaServices.MailMessageSummary

public enum OutboxState: Equatable, Sendable {
    case waiting
    case sending
    case failed(Hint)
}

public struct OutboxItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let inlet: Inlet.ID
    public let draft: EmailDraft
    public let messageID: String
    public internal(set) var draftID: String?
    public private(set) var state: OutboxState
    public private(set) var attempts: Int

    public init(inlet: Inlet.ID, draft: EmailDraft, draftID: String? = nil) {
        self.init(id: UUID(), inlet: inlet, draft: draft, messageID: UUID().uuidString.lowercased(), draftID: draftID,
                  state: .waiting, attempts: 0)
    }

    init(id: UUID, inlet: Inlet.ID, draft: EmailDraft, messageID: String, draftID: String?, state: OutboxState, attempts: Int) {
        self.id = id
        self.inlet = inlet
        self.draft = draft
        self.messageID = messageID
        self.draftID = draftID
        self.state = state
        self.attempts = attempts
    }

    mutating func startSending() {
        state = .sending
        attempts += 1
    }

    mutating func wait() { state = .waiting }

    mutating func fail(_ hint: Hint) { state = .failed(hint) }
}

public enum SendOutcome: Equatable, Sendable {
    case sent
    case queued(OutboxItem.ID)
}

public enum MailEngineEvent: Equatable, Sendable {
    case accountsChanged
    case foldersChanged(Inlet.ID)
    case messagesChanged(Inlet.ID, folder: String)
    case newMail(Inlet.ID, count: Int)
    case outboxChanged
    case syncFailed(Inlet.ID, Hint)
    case syncFinished(Inlet.ID)
}

@MainActor
public protocol MailEngine: AnyObject {
    var accounts: [Inlet] { get }
    func folders(_ inlet: Inlet.ID) -> [MailFolder]
    func refreshFolders(_ inlet: Inlet.ID) async throws(HubError)
    func messages(_ inlet: Inlet.ID, folder: String) -> [MailMessageSummary]
    func lastSync(_ inlet: Inlet.ID, folder: String) -> Date?
    func loadPage(_ inlet: Inlet.ID, folder: String, query: String?, pageToken: String?) async throws(HubError) -> MailMessagePage
    func searchLocal(_ inlet: Inlet.ID, query: String) -> [MailMessageSummary]
    func searchOpen(_ inlet: Inlet.ID, query: String, excluding folders: Set<String>) async -> [MailMessageSummary]
    func body(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailMessageBody
    func setFlags(_ inlet: Inlet.ID, messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws(HubError)
    @discardableResult func archive(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> String?
    @discardableResult func move(_ inlet: Inlet.ID, messageID: String, toFolder: String) async throws(HubError) -> String?
    @discardableResult func trash(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> String?
    func markSpam(_ inlet: Inlet.ID, messageID: String) async throws(HubError)
    func purge(_ inlet: Inlet.ID, messageID: String) async throws(HubError)
    func attachment(_ inlet: Inlet.ID, messageID: String, attachmentID: String) async throws(HubError) -> Data
    func thread(_ inlet: Inlet.ID, messageID: String, threadID: String) async throws(HubError) -> [MailMessageSummary]
    func saveDraft(_ inlet: Inlet.ID, _ draft: EmailDraft, replacing draftID: String?) async throws(HubError) -> String
    func loadDraft(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailStoredDraft
    func deleteDraft(_ inlet: Inlet.ID, draftID: String) async throws(HubError)
    func send(_ inlet: Inlet.ID, _ draft: EmailDraft) async -> SendOutcome
    func sendDraft(_ inlet: Inlet.ID, draftID: String, _ draft: EmailDraft) async -> SendOutcome
    var outbox: [OutboxItem] { get }
    func retryOutbox() async
    func resend(_ id: OutboxItem.ID, _ draft: EmailDraft, draftID: String?) async -> SendOutcome?
    func revise(_ id: OutboxItem.ID, _ draft: EmailDraft)
    func unreadCount(_ inlet: Inlet.ID) -> Int
    var events: AsyncStream<MailEngineEvent> { get }
    var hasFiles: Bool { get }
    func projectFolders() async throws(HubError) -> [ProjectFolderRecord]
    func listFiles(_ inlet: Inlet.ID, folder: String) async throws(HubError) -> [FileEntry]
    func readFile(_ inlet: Inlet.ID, fileID: String) async throws(HubError) -> Data
    func putFile(_ inlet: Inlet.ID, folder: String, name: String, mimeType: String, data: Data) async throws(HubError) -> FileEntry
}

extension MailEngine {
    public func searchOpen(_ inlet: Inlet.ID, query: String, excluding folders: Set<String>) async -> [MailMessageSummary] {
        searchLocal(inlet, query: query).filter { !$0.folderIDs.contains(where: folders.contains) }
    }
    public func purge(_ inlet: Inlet.ID, messageID: String) async throws(HubError) {
        throw HubError.capabilityMissing(inlet, .mail)
    }
    public func resend(_ id: OutboxItem.ID, _ draft: EmailDraft, draftID: String?) async -> SendOutcome? { nil }
    public func revise(_ id: OutboxItem.ID, _ draft: EmailDraft) {}
    public var hasFiles: Bool { false }
    public func projectFolders() async throws(HubError) -> [ProjectFolderRecord] { throw HubError.noInlet(.files) }
    public func listFiles(_ inlet: Inlet.ID, folder: String) async throws(HubError) -> [FileEntry] {
        throw HubError.capabilityMissing(inlet, .files)
    }
    public func readFile(_ inlet: Inlet.ID, fileID: String) async throws(HubError) -> Data {
        throw HubError.capabilityMissing(inlet, .files)
    }
    public func putFile(_ inlet: Inlet.ID, folder: String, name: String, mimeType: String, data: Data) async throws(HubError) -> FileEntry {
        throw HubError.capabilityMissing(inlet, .files)
    }
}
