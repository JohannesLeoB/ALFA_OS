import Foundation
import Hub
@testable import Mail
import struct AlfaKit.EmailDraft
import protocol AlfaServices.MailTransport
import enum AlfaServices.MailFlag
import struct AlfaServices.MailFolder
import struct AlfaServices.MailStoredDraft
import struct AlfaServices.MailMessageBody
import struct AlfaServices.MailMessagePage
import struct AlfaServices.MailMessageSummary
import enum AlfaServices.GoogleGmailError
import enum AlfaServices.MailTransportError

final class TransportDouble: MailTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _folders: [MailFolder] = []
    private var _pages: [String: MailMessagePage] = [:]
    private var _tokenPages: [String: MailMessagePage] = [:]
    private var _failures: [Int: Error] = [:]
    private var _sendError: Error?
    private var _listError: Error?
    private var _sent: [EmailDraft] = []
    private var _sendCalls = 0
    private var _listCalls = 0

    var folders: [MailFolder] { get { lock.withLock { _folders } } set { lock.withLock { _folders = newValue } } }
    var sendError: Error? { get { lock.withLock { _sendError } } set { lock.withLock { _sendError = newValue } } }
    var listError: Error? { get { lock.withLock { _listError } } set { lock.withLock { _listError = newValue } } }
    var sent: [EmailDraft] { lock.withLock { _sent } }
    var sendCalls: Int { lock.withLock { _sendCalls } }

    func setPage(_ folder: String, _ page: MailMessagePage) { lock.withLock { _pages[folder] = page } }
    func setTokenPage(_ token: String?, _ page: MailMessagePage) { lock.withLock { _tokenPages[token ?? "-"] = page } }
    func failList(call: Int, _ error: Error) { lock.withLock { _failures[call] = error } }

    func listFolders() async throws -> [MailFolder] {
        if let error = listError { throw error }
        return folders
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage {
        if let error = listError { throw error }
        let (failure, page) = lock.withLock { () -> (Error?, MailMessagePage?) in
            _listCalls += 1
            return (_failures[_listCalls], _pages[folderID] ?? _tokenPages[pageToken ?? "-"])
        }
        if let failure { throw failure }
        return page ?? MailMessagePage(messages: [])
    }

    func fetchBody(messageID: String) async throws -> MailMessageBody { MailMessageBody(text: "body") }

    func send(_ draft: EmailDraft) async throws {
        lock.withLock { _sendCalls += 1 }
        if let error = sendError { throw error }
        lock.withLock { _sent.append(draft) }
    }

    func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {}

    private var _calls: [String] = []
    private var _actionError: Error?
    private var _attachment = Data()
    private var _thread: [MailMessageSummary] = []
    private var _stored: MailStoredDraft?
    private var _savedID = "draft-1"

    var calls: [String] { lock.withLock { _calls } }
    var actionError: Error? { get { lock.withLock { _actionError } } set { lock.withLock { _actionError = newValue } } }
    var attachment: Data { get { lock.withLock { _attachment } } set { lock.withLock { _attachment = newValue } } }
    var thread: [MailMessageSummary] { get { lock.withLock { _thread } } set { lock.withLock { _thread = newValue } } }
    var stored: MailStoredDraft? { get { lock.withLock { _stored } } set { lock.withLock { _stored = newValue } } }
    var savedID: String { get { lock.withLock { _savedID } } set { lock.withLock { _savedID = newValue } } }

    private func record(_ call: String) throws {
        let error = lock.withLock { () -> Error? in
            _calls.append(call)
            return _actionError
        }
        if let error { throw error }
    }

    func archive(messageID: String) async throws { try record("archive:" + messageID) }
    func move(messageID: String, toFolderID: String) async throws { try record("move:" + messageID + ">" + toFolderID) }
    func trash(messageID: String) async throws { try record("trash:" + messageID) }
    func markSpam(messageID: String) async throws { try record("spam:" + messageID) }

    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data {
        try record("attachment:" + messageID + "/" + attachmentID)
        return attachment
    }

    func fetchThread(messageID: String, threadID: String) async throws -> [MailMessageSummary] {
        try record("thread:" + messageID + "/" + threadID)
        return thread
    }

    func saveDraft(_ draft: EmailDraft, replacing draftID: String?) async throws -> String {
        try record("saveDraft:" + (draftID ?? "-") + ":" + draft.subject)
        return savedID
    }

    func fetchDraft(messageID: String) async throws -> MailStoredDraft {
        try record("fetchDraft:" + messageID)
        guard let stored else { throw MailTransportError.messageNotFound(messageID) }
        return stored
    }

    func deleteDraft(id: String) async throws { try record("deleteDraft:" + id) }

    func sendDraft(id: String) async throws {
        try record("sendDraft:" + id)
        lock.withLock { _sendCalls += 1 }
    }
}

func mailTestClassify(_ error: Error) -> Classification {
    if error is GoogleGmailError {
        return GoogleProvider(config: GoogleClientConfig(clientID: "id", clientSecret: ""),
                              openBrowser: { _ in false }).classify(error)
    }
    return IMAPProvider().classify(error)
}

@MainActor
final class HubDouble: HubAccess {
    var mailInlets: [Inlet] = []
    var transports: [Inlet.ID: TransportDouble] = [:]
    private let stream: AsyncStream<HubEvent>
    private let continuation: AsyncStream<HubEvent>.Continuation

    init() {
        (stream, continuation) = AsyncStream<HubEvent>.makeStream()
    }

    var events: AsyncStream<HubEvent> { stream }

    func push(_ event: HubEvent) { continuation.yield(event) }

    func inlets(for capability: Capability) -> [Inlet] {
        capability == .mail ? mailInlets : []
    }

    func port<P>(_ port: P.Type, for inlet: Inlet.ID) throws(HubError) -> P {
        guard let known = mailInlets.first(where: { $0.id == inlet }), known.state.isConnected,
              let transport = transports[inlet] as? P else { throw .notConnected(inlet) }
        return transport
    }

    func stock<T: Record>(_ kind: DataKind, as type: T.Type) -> Stock<T> {
        fatalError()
    }

    func write(_ order: WriteOrder) async throws(HubError) {}

    func classify(_ error: any Error, inlet: Inlet.ID) -> Classification { mailTestClassify(error) }

    func health(of inlet: Inlet.ID) -> InletHealth { .online }

    func add(_ id: Inlet.ID, connected: Bool = true) -> TransportDouble {
        let transport = TransportDouble()
        transports[id] = transport
        mailInlets.append(Inlet(id: id, provider: "test", capabilities: [.mail], owner: .person("p"), title: id,
                                state: connected ? .connected(probed: Date()) : .failed(Hint(text: "x"))))
        return transport
    }

    func remove(_ id: Inlet.ID) {
        mailInlets.removeAll { $0.id == id }
        transports[id] = nil
    }
}

func message(_ id: String, seen: Bool = false, subject: String = "s") -> MailMessageSummary {
    MailMessageSummary(id: id, subject: subject, from: "a", flags: seen ? [.seen] : [])
}

func draft() -> EmailDraft {
    EmailDraft(to: "z@example.test", subject: "s", body: "b")
}

@MainActor
func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<200 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
