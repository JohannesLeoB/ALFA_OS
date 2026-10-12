import Foundation
import class GRDB.DatabaseQueue
import Hub
@testable import Mail
import struct MykilosKit.EmailDraft
import protocol MykilosServices.MailTransport
import enum MykilosServices.MailFlag
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessageBody
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageSummary
import enum MykilosServices.MailTransportError

final class TransportDouble: MailTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _folders: [MailFolder] = []
    private var _pages: [String: MailMessagePage] = [:]
    private var _sendError: Error?
    private var _listError: Error?
    private var _sent: [EmailDraft] = []
    private var _sendCalls = 0

    var folders: [MailFolder] { get { lock.withLock { _folders } } set { lock.withLock { _folders = newValue } } }
    var sendError: Error? { get { lock.withLock { _sendError } } set { lock.withLock { _sendError = newValue } } }
    var listError: Error? { get { lock.withLock { _listError } } set { lock.withLock { _listError = newValue } } }
    var sent: [EmailDraft] { lock.withLock { _sent } }
    var sendCalls: Int { lock.withLock { _sendCalls } }

    func setPage(_ folder: String, _ page: MailMessagePage) { lock.withLock { _pages[folder] = page } }

    func listFolders() async throws -> [MailFolder] {
        if let error = listError { throw error }
        return folders
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage {
        if let error = listError { throw error }
        return lock.withLock { _pages[folderID] } ?? MailMessagePage(messages: [])
    }

    func fetchBody(messageID: String) async throws -> MailMessageBody { MailMessageBody(text: "body") }

    func send(_ draft: EmailDraft) async throws {
        lock.withLock { _sendCalls += 1 }
        if let error = sendError { throw error }
        lock.withLock { _sent.append(draft) }
    }

    func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {}
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

    func add(_ id: Inlet.ID, connected: Bool = true) -> TransportDouble {
        let transport = TransportDouble()
        transports[id] = transport
        mailInlets.append(Inlet(id: id, provider: "test", capabilities: [.mail], owner: .person("p"), title: id,
                                state: connected ? .connected(probed: Date()) : .failed(Hint(text: "x"))))
        return transport
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
