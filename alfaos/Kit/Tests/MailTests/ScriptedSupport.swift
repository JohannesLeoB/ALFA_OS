import Foundation
import Hub
@testable import Mail
import struct AlfaKit.EmailDraft
import enum AlfaServices.MailFlag
import struct AlfaServices.MailFolder
import struct AlfaServices.MailMessageBody
import struct AlfaServices.MailMessagePage
import struct AlfaServices.MailMessageSummary
import struct AlfaServices.MailStoredDraft

@MainActor
final class ScriptedGate {
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
final class ScriptedEngine: MailEngine {
    var accounts: [Inlet] = []
    var folderList: [String: [MailFolder]] = [:]
    var pendingFolders: [String: [MailFolder]] = [:]
    var pages: [String: MailMessagePage] = [:]
    var pageGates: [String: ScriptedGate] = [:]
    var folderGates: [String: ScriptedGate] = [:]
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

    func archive(_ inlet: Inlet.ID, messageID: String) async throws(HubError) {}
    func move(_ inlet: Inlet.ID, messageID: String, toFolder: String) async throws(HubError) {}
    func trash(_ inlet: Inlet.ID, messageID: String) async throws(HubError) {}
    func markSpam(_ inlet: Inlet.ID, messageID: String) async throws(HubError) {}
    func attachment(_ inlet: Inlet.ID, messageID: String, attachmentID: String) async throws(HubError) -> Data { Data() }
    func thread(_ inlet: Inlet.ID, messageID: String, threadID: String) async throws(HubError) -> [MailMessageSummary] { [] }
    func saveDraft(_ inlet: Inlet.ID, _ draft: EmailDraft, replacing draftID: String?) async throws(HubError) -> String { "" }
    func loadDraft(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailStoredDraft {
        MailStoredDraft(id: "", draft: EmailDraft(subject: "", body: ""))
    }
    func deleteDraft(_ inlet: Inlet.ID, draftID: String) async throws(HubError) {}
    func sendDraft(_ inlet: Inlet.ID, draftID: String, _ draft: EmailDraft) async -> SendOutcome { .sent }
    func send(_ inlet: Inlet.ID, _ draft: EmailDraft) async -> SendOutcome { .sent }
    func retryOutbox() async {}
    func unreadCount(_ inlet: Inlet.ID) -> Int { 0 }
}

let scriptedInbox = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
