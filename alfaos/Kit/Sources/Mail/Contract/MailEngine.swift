import Foundation
import Hub
import struct MykilosKit.EmailDraft
import enum MykilosServices.MailFlag
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessageBody
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageSummary

public enum OutboxState: Equatable, Sendable {
    case waiting
    case sending
    case failed(Hint)
}

public struct OutboxItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let inlet: Inlet.ID
    public let draft: EmailDraft
    public var state: OutboxState
    public var attempts: Int

    public init(id: UUID = UUID(), inlet: Inlet.ID, draft: EmailDraft, state: OutboxState = .waiting, attempts: Int = 0) {
        self.id = id
        self.inlet = inlet
        self.draft = draft
        self.state = state
        self.attempts = attempts
    }
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
    func send(_ inlet: Inlet.ID, _ draft: EmailDraft) async -> SendOutcome
    var outbox: [OutboxItem] { get }
    func retryOutbox() async
    func unreadCount(_ inlet: Inlet.ID) -> Int
    var events: AsyncStream<MailEngineEvent> { get }
}

public enum MailHintKey {
    public static let offline = "mail.hint.offline"
    public static let signIn = "mail.hint.signIn"
    public static let rejected = "mail.hint.rejected"
    public static let failed = "mail.hint.failed"
}
