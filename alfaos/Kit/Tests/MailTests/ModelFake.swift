import Foundation
import Hub
import Mail
import struct MykilosKit.EmailDraft
import enum MykilosServices.MailFlag
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessageBody
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageSummary
import struct MykilosServices.MailStoredDraft

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
    var actionError: HubError?
    var actionCalls: [String] = []
    var attachmentData = Data()
    var threadMessages: [MailMessageSummary] = []
    var savedDraftID = "remote-1"
    var storedDraft: MailStoredDraft?
    var savedDrafts: [(draft: EmailDraft, replacing: String?)] = []
    var sentFromDraft: [(id: String, draft: EmailDraft)] = []
    var saveGate: CheckedContinuation<Void, Never>?
    var holdSave = false
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

    private func act(_ call: String) throws(HubError) {
        actionCalls.append(call)
        if let actionError { throw actionError }
    }

    func archive(_ inlet: Inlet.ID, messageID: String) async throws(HubError) { try act("archive:" + messageID) }
    func move(_ inlet: Inlet.ID, messageID: String, toFolder: String) async throws(HubError) {
        try act("move:" + messageID + ">" + toFolder)
    }
    func trash(_ inlet: Inlet.ID, messageID: String) async throws(HubError) { try act("trash:" + messageID) }
    func markSpam(_ inlet: Inlet.ID, messageID: String) async throws(HubError) { try act("spam:" + messageID) }

    func attachment(_ inlet: Inlet.ID, messageID: String, attachmentID: String) async throws(HubError) -> Data {
        try act("attachment:" + messageID + "/" + attachmentID)
        return attachmentData
    }

    func thread(_ inlet: Inlet.ID, messageID: String, threadID: String) async throws(HubError) -> [MailMessageSummary] {
        try act("thread:" + messageID + "/" + threadID)
        return threadMessages
    }

    func saveDraft(_ inlet: Inlet.ID, _ draft: EmailDraft, replacing draftID: String?) async throws(HubError) -> String {
        if holdSave { await withCheckedContinuation { saveGate = $0 } }
        try act("saveDraft")
        savedDrafts.append((draft, draftID))
        return savedDraftID
    }

    func loadDraft(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailStoredDraft {
        try act("loadDraft:" + messageID)
        return storedDraft ?? MailStoredDraft(id: "remote-9", draft: EmailDraft(subject: "stored", body: "text"))
    }

    func deleteDraft(_ inlet: Inlet.ID, draftID: String) async throws(HubError) { try act("deleteDraft:" + draftID) }

    func sendDraft(_ inlet: Inlet.ID, draftID: String, _ draft: EmailDraft) async -> SendOutcome {
        sentFromDraft.append((draftID, draft))
        return sendOutcome
    }

    func retryOutbox() async {}
    func unreadCount(_ inlet: Inlet.ID) -> Int { unread[inlet] ?? 0 }

    func release() {
        gate?.resume()
        gate = nil
        saveGate?.resume()
        saveGate = nil
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
