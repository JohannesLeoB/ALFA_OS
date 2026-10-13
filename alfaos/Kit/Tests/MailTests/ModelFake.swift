import Foundation
import Hub
import Mail
import struct MykilosKit.EmailDraft
import enum MykilosServices.MailFlag
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessageBody
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageSummary

@MainActor
final class ModelFakeEngine: MailEngine {
    var accounts: [Inlet] = []
    var folderList: [String: [MailFolder]] = [:]
    var mirror: [String: [MailMessageSummary]] = [:]
    var pages: [String?: MailMessagePage] = [:]
    var searchHits: [MailMessageSummary] = []
    var bodies: [String: MailMessageBody] = [:]
    var pageError: HubError?
    var bodyError: HubError?
    var flagError: HubError?
    var sendOutcome: SendOutcome = .sent
    var sentDrafts: [EmailDraft] = []
    var flagCalls: [(String, Set<MailFlag>, Set<MailFlag>)] = []
    var unread: [Inlet.ID: Int] = [:]
    var outbox: [OutboxItem] = []
    var gate: CheckedContinuation<Void, Never>?
    var holdPages = false
    let events: AsyncStream<MailEngineEvent>
    let feed: AsyncStream<MailEngineEvent>.Continuation

    init() {
        (events, feed) = AsyncStream<MailEngineEvent>.makeStream()
    }

    func folders(_ inlet: Inlet.ID) -> [MailFolder] { folderList[inlet] ?? [] }
    func refreshFolders(_ inlet: Inlet.ID) async throws(HubError) {}
    func messages(_ inlet: Inlet.ID, folder: String) -> [MailMessageSummary] { mirror[inlet + folder] ?? [] }
    func lastSync(_ inlet: Inlet.ID, folder: String) -> Date? { Date(timeIntervalSince1970: 100) }

    func loadPage(_ inlet: Inlet.ID, folder: String, query: String?, pageToken: String?) async throws(HubError)
        -> MailMessagePage {
        if holdPages { await withCheckedContinuation { gate = $0 } }
        if let pageError { throw pageError }
        return pages[pageToken] ?? MailMessagePage(messages: [])
    }

    func searchLocal(_ inlet: Inlet.ID, query: String) -> [MailMessageSummary] { searchHits }

    func body(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailMessageBody {
        if let bodyError { throw bodyError }
        return bodies[messageID] ?? MailMessageBody(text: "text of " + messageID)
    }

    func setFlags(_ inlet: Inlet.ID, messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>)
        async throws(HubError) {
        if let flagError { throw flagError }
        flagCalls.append((messageID, add, remove))
    }

    func send(_ inlet: Inlet.ID, _ draft: EmailDraft) async -> SendOutcome {
        sentDrafts.append(draft)
        return sendOutcome
    }

    func retryOutbox() async {}
    func unreadCount(_ inlet: Inlet.ID) -> Int { unread[inlet] ?? 0 }

    func release() {
        gate?.resume()
        gate = nil
    }
}

func fakeAccount(_ id: String, state: InletState = .connected(probed: Date()), address: String = "me@x.test")
    -> Inlet {
    Inlet(id: id, provider: "p", capabilities: [.mail], owner: .company, title: id, account: address, state: state)
}

func fakeMessage(_ id: String, flags: Set<MailFlag> = [], attachments: Int = 0, thread: String = "",
                 from: String = "Anna Berg <anna@x.test>", subject: String = "Hello") -> MailMessageSummary {
    MailMessageSummary(id: id, threadID: thread, subject: subject, from: from, fromRaw: from,
                       toRaw: "me@x.test, bob@x.test", ccRaw: "carl@x.test", snippet: "snip " + id,
                       flags: flags, attachmentCount: attachments)
}
