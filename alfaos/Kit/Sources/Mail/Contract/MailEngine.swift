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
    public let draftID: String?
    public private(set) var state: OutboxState
    public private(set) var attempts: Int

    public init(inlet: Inlet.ID, draft: EmailDraft, draftID: String? = nil) {
        self.init(id: UUID(), inlet: inlet, draft: draft, draftID: draftID, state: .waiting, attempts: 0)
    }

    init(id: UUID, inlet: Inlet.ID, draft: EmailDraft, draftID: String?, state: OutboxState, attempts: Int) {
        self.id = id
        self.inlet = inlet
        self.draft = draft
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
    func unreadCount(_ inlet: Inlet.ID) -> Int
    var events: AsyncStream<MailEngineEvent> { get }
}

extension MailEngine {
    public func purge(_ inlet: Inlet.ID, messageID: String) async throws(HubError) {
        throw HubError.capabilityMissing(inlet, .mail)
    }
}
