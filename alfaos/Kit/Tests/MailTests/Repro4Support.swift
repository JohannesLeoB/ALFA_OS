import Foundation
import Hub
@testable import Mail
import struct MykilosKit.EmailDraft
import protocol MykilosServices.MailTransport
import enum MykilosServices.MailFlag
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessageBody
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageSummary

@MainActor
final class Repro4Gate {
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    var hasWaiter: Bool { !waiting.isEmpty }

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func release() {
        isOpen = true
        let all = waiting
        waiting = []
        for continuation in all { continuation.resume() }
    }
}

@MainActor
final class Repro4Engine: MailEngine {
    var accounts: [Inlet] = []
    var folderList: [String: [MailFolder]] = [:]
    var pendingFolders: [String: [MailFolder]] = [:]
    var pages: [String: MailMessagePage] = [:]
    var pageGates: [String: Repro4Gate] = [:]
    var folderGates: [String: Repro4Gate] = [:]
    var pageCalls: [String] = []
    var flagCalls: [String] = []
    var bodyError: HubError?
    var outbox: [OutboxItem] = []
    let events: AsyncStream<MailEngineEvent>
    let feed: AsyncStream<MailEngineEvent>.Continuation

    init() {
        (events, feed) = AsyncStream<MailEngineEvent>.makeStream()
    }

    static func key(_ inlet: String, _ folder: String, _ token: String?) -> String {
        inlet + "|" + folder + "|" + (token ?? "-")
    }

    func folders(_ inlet: Inlet.ID) -> [MailFolder] { folderList[inlet] ?? [] }

    func refreshFolders(_ inlet: Inlet.ID) async throws(HubError) {
        if let gate = folderGates[inlet] { await gate.wait() }
        if let pending = pendingFolders[inlet] { folderList[inlet] = pending }
    }

    func messages(_ inlet: Inlet.ID, folder: String) -> [MailMessageSummary] { [] }
    func lastSync(_ inlet: Inlet.ID, folder: String) -> Date? { nil }

    func loadPage(_ inlet: Inlet.ID, folder: String, query: String?, pageToken: String?) async throws(HubError)
        -> MailMessagePage {
        let key = Self.key(inlet, folder, pageToken)
        pageCalls.append(key)
        if let gate = pageGates[key] { await gate.wait() }
        return pages[key] ?? MailMessagePage(messages: [])
    }

    func searchLocal(_ inlet: Inlet.ID, query: String) -> [MailMessageSummary] { [] }

    func body(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailMessageBody {
        if let bodyError { throw bodyError }
        return MailMessageBody(text: "text of " + messageID)
    }

    func setFlags(_ inlet: Inlet.ID, messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>)
        async throws(HubError) {
        flagCalls.append(messageID + "+" + add.map(\.rawValue).sorted().joined(separator: ","))
    }

    func send(_ inlet: Inlet.ID, _ draft: EmailDraft) async -> SendOutcome { .sent }
    func retryOutbox() async {}
    func unreadCount(_ inlet: Inlet.ID) -> Int { 0 }
}

final class ScriptTransport: MailTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _folders: [MailFolder] = []
    private var _pages: [String: MailMessagePage] = [:]
    private var _failures: [Int: Error] = [:]
    private var _listCalls = 0
    private var _sendError: Error?
    private var _sent: [EmailDraft] = []

    var folders: [MailFolder] { get { lock.withLock { _folders } } set { lock.withLock { _folders = newValue } } }
    var sendError: Error? { get { lock.withLock { _sendError } } set { lock.withLock { _sendError = newValue } } }
    var listCalls: Int { lock.withLock { _listCalls } }
    var sent: [EmailDraft] { lock.withLock { _sent } }

    func setPage(_ token: String?, _ page: MailMessagePage) { lock.withLock { _pages[token ?? "-"] = page } }
    func failList(call: Int, _ error: Error) { lock.withLock { _failures[call] = error } }

    func listFolders() async throws -> [MailFolder] { folders }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage {
        let (call, failure, page) = lock.withLock {
            _listCalls += 1
            return (_listCalls, _failures[_listCalls], _pages[pageToken ?? "-"])
        }
        _ = call
        if let failure { throw failure }
        return page ?? MailMessagePage(messages: [])
    }

    func fetchBody(messageID: String) async throws -> MailMessageBody { MailMessageBody(text: "body") }

    func send(_ draft: EmailDraft) async throws {
        if let error = sendError { throw error }
        lock.withLock { _sent.append(draft) }
    }

    func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {}
}

@MainActor
final class Repro4Hub: HubAccess {
    var mailInlets: [Inlet] = []
    var transports: [Inlet.ID: ScriptTransport] = [:]
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

    func add(_ id: Inlet.ID) -> ScriptTransport {
        let transport = ScriptTransport()
        transports[id] = transport
        mailInlets.append(Inlet(id: id, provider: "test", capabilities: [.mail], owner: .person("p"), title: id,
                                state: .connected(probed: Date())))
        return transport
    }

    func remove(_ id: Inlet.ID) {
        mailInlets.removeAll { $0.id == id }
        transports[id] = nil
    }
}

let repro4Inbox = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
