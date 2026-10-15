import GRDB
import Hub
@testable import Mail
import struct MykilosKit.EmailDraft
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageSummary
import struct MykilosServices.MailStoredDraft
import enum MykilosServices.MailTransportError
import XCTest

@MainActor
final class CoreActionTests: XCTestCase {
    private func make() async throws -> (MailCore, TransportDouble, HubDouble) {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox), MailFolder(id: "WORK", name: "Work", role: .other)]
        transport.setPage("INBOX", MailMessagePage(messages: [message("1"), message("2")]))
        transport.setPage("WORK", MailMessagePage(messages: [message("1"), message("3")]))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        _ = try await core.loadPage("one", folder: "WORK", query: nil, pageToken: nil)
        return (core, transport, hub)
    }

    private func collect(_ core: MailCore, during work: () async throws -> Void) async rethrows -> [MailEngineEvent] {
        var seen: [MailEngineEvent] = []
        let stream = core.events
        let task = Task { @MainActor in
            for await event in stream { seen.append(event) }
        }
        await Task.yield()
        try await work()
        await Task.yield()
        task.cancel()
        await task.value
        return seen
    }

    private func stepArchiveLeavesTheInboxOnlyAndTellsTheListSo() async throws {
        let (core, transport, _) = try await make()
        let events = try await collect(core) { try await core.archive("one", messageID: "1") }
        XCTAssertEqual(transport.calls, ["archive:1"])
        XCTAssertEqual(core.messages("one", folder: "INBOX").map(\.id), ["2"])
        XCTAssertEqual(core.messages("one", folder: "WORK").map(\.id), ["1", "3"])
        XCTAssertEqual(core.unreadCount("one"), 1)
        XCTAssertEqual(events, [.messagesChanged("one", folder: "INBOX")])
    }

    private func stepTrashAndSpamLeaveEveryFolder() async throws {
        let (core, transport, _) = try await make()
        try await core.trash("one", messageID: "1")
        XCTAssertEqual(core.messages("one", folder: "INBOX").map(\.id), ["2"])
        XCTAssertEqual(core.messages("one", folder: "WORK").map(\.id), ["3"])
        try await core.markSpam("one", messageID: "3")
        XCTAssertEqual(core.messages("one", folder: "WORK").map(\.id), [])
        XCTAssertEqual(transport.calls, ["trash:1", "spam:3"])
    }

    private func stepMoveAsksTheTransportForTheTargetAndDropsTheMessageFromTheMirror() async throws {
        let (core, transport, _) = try await make()
        try await core.move("one", messageID: "2", toFolder: "WORK")
        XCTAssertEqual(transport.calls, ["move:2>WORK"])
        XCTAssertEqual(core.messages("one", folder: "INBOX").map(\.id), ["1"])
    }

    private func stepAProviderRefusalKeepsTheMessageAndCarriesTheOriginalAnswer() async throws {
        let (core, transport, _) = try await make()
        transport.actionError = MailTransportError.serverRejected("NO [CANNOT] folder is read only")
        do {
            try await core.trash("one", messageID: "1")
            XCTFail("trash must throw")
        } catch {
            guard case .provider(let hint) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(hint.text, "mail.hint.rejected")
            XCTAssertEqual(hint.detail, "NO [CANNOT] folder is read only")
        }
        XCTAssertEqual(core.messages("one", folder: "INBOX").map(\.id), ["1", "2"])
    }

    private func stepAttachmentAndThreadComeFromTheTransport() async throws {
        let (core, transport, _) = try await make()
        transport.attachment = Data("pdf".utf8)
        transport.thread = [message("1"), message("2")]
        let data = try await core.attachment("one", messageID: "1", attachmentID: "a")
        let thread = try await core.thread("one", messageID: "2", threadID: "t")
        XCTAssertEqual(data, Data("pdf".utf8))
        XCTAssertEqual(thread.map(\.id), ["1", "2"])
        XCTAssertEqual(transport.calls, ["attachment:1/a", "thread:2/t"])
    }

    private func stepDraftsAreSavedLoadedAndDeletedThroughTheTransport() async throws {
        let (core, transport, _) = try await make()
        transport.stored = MailStoredDraft(id: "d7", draft: draft())
        let id = try await core.saveDraft("one", draft(), replacing: "d1")
        let stored = try await core.loadDraft("one", messageID: "m7")
        try await core.deleteDraft("one", draftID: "d7")
        XCTAssertEqual(id, "draft-1")
        XCTAssertEqual(stored.id, "d7")
        XCTAssertEqual(transport.calls, ["saveDraft:d1:s", "fetchDraft:m7", "deleteDraft:d7"])
    }

    private func stepSendingFromADraftStoresTheLatestTextThenSendsTheDraft() async throws {
        let (core, transport, _) = try await make()
        let outcome = await core.sendDraft("one", draftID: "d1", draft())
        XCTAssertEqual(outcome, .sent)
        XCTAssertEqual(transport.calls, ["saveDraft:d1:s", "sendDraft:draft-1"])
        XCTAssertTrue(transport.sent.isEmpty)
        XCTAssertTrue(core.outbox.isEmpty)
    }

    private func stepAQueuedDraftKeepsItsDraftThroughARestartAndGoesOutAsADraft() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.actionError = MailTransportError.timeout
        let database = try DatabaseQueue()
        let first = try MailCore(hub: hub, database: database)
        let outcome = await first.sendDraft("one", draftID: "d1", draft())
        guard case .queued = outcome else { return XCTFail("expected queued") }
        let second = try MailCore(hub: hub, database: database)
        XCTAssertEqual(second.outbox.first?.draftID, "d1")
        transport.actionError = nil
        await second.retryOutbox()
        XCTAssertTrue(second.outbox.isEmpty)
        XCTAssertTrue(transport.sent.isEmpty)
        XCTAssertEqual(transport.calls.suffix(2), ["saveDraft:d1:s", "sendDraft:draft-1"])
    }

    func testTheCoreActions() async throws {
        try await stepArchiveLeavesTheInboxOnlyAndTellsTheListSo()
        try await stepTrashAndSpamLeaveEveryFolder()
        try await stepMoveAsksTheTransportForTheTargetAndDropsTheMessageFromTheMirror()
        try await stepAProviderRefusalKeepsTheMessageAndCarriesTheOriginalAnswer()
        try await stepAttachmentAndThreadComeFromTheTransport()
        try await stepDraftsAreSavedLoadedAndDeletedThroughTheTransport()
        try await stepSendingFromADraftStoresTheLatestTextThenSendsTheDraft()
        try await stepAQueuedDraftKeepsItsDraftThroughARestartAndGoesOutAsADraft()
    }
}
