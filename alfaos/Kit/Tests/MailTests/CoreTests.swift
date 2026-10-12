import GRDB
import Hub
@testable import Mail
import struct MykilosKit.EmailDraft
import enum MykilosServices.MailFlag
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import enum MykilosServices.MailTransportError
import XCTest

@MainActor
final class CoreTests: XCTestCase {
    private func make() throws -> (MailCore, HubDouble, TransportDouble, TransportDouble) {
        let hub = HubDouble()
        let one = hub.add("one")
        let two = hub.add("two")
        for transport in [one, two] {
            transport.folders = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox), MailFolder(id: "S", name: "Sent", role: .sent)]
        }
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        return (core, hub, one, two)
    }

    func testAccountsAndFoldersComeFromTheHub() async throws {
        let (core, _, _, _) = try make()
        XCTAssertEqual(core.accounts.map(\.id), ["one", "two"])
        XCTAssertTrue(core.folders("one").isEmpty)
        try await core.refreshFolders("one")
        XCTAssertEqual(core.folders("one").map(\.id), ["INBOX", "S"])
        XCTAssertEqual(core.folders("one").first?.role, .inbox)
        XCTAssertTrue(core.folders("two").isEmpty)
    }

    func testNotConnectedSurfacesAsHubError() async throws {
        let hub = HubDouble()
        _ = hub.add("off", connected: false)
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        do {
            try await core.refreshFolders("off")
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error, .notConnected("off"))
        }
    }

    func testLoadPageFillsMirror() async throws {
        let (core, _, one, _) = try make()
        one.setPage("INBOX", MailMessagePage(messages: [message("1"), message("2", seen: true)], nextPageToken: "t"))
        let page = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        XCTAssertEqual(page.nextPageToken, "t")
        XCTAssertEqual(core.messages("one", folder: "INBOX").map(\.id), ["1", "2"])
        XCTAssertEqual(core.messages("one", folder: "INBOX").last?.flags, [.seen])
        XCTAssertNotNil(core.lastSync("one", folder: "INBOX"))
        XCTAssertNil(core.lastSync("one", folder: "S"))
        one.setPage("INBOX", MailMessagePage(messages: [message("3")]))
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: "t")
        XCTAssertEqual(core.messages("one", folder: "INBOX").map(\.id), ["1", "2", "3"])
        XCTAssertEqual(core.searchLocal("one", query: "s").count, 3)
    }

    func testSendWithoutNetworkQueuesAndRetrySends() async throws {
        let (core, _, one, _) = try make()
        one.sendError = MailTransportError.connectionFailed("down")
        let outcome = await core.send("one", draft())
        guard case .queued(let id) = outcome else { return XCTFail("expected queued") }
        XCTAssertEqual(core.outbox.map(\.id), [id])
        XCTAssertEqual(core.outbox.first?.state, .waiting)
        one.sendError = nil
        await core.retryOutbox()
        XCTAssertEqual(one.sent.count, 1)
        XCTAssertTrue(core.outbox.isEmpty)
    }

    func testOutboxSurvivesAReopenedDatabase() async throws {
        let hub = HubDouble()
        let one = hub.add("one")
        one.sendError = MailTransportError.timeout
        let database = try DatabaseQueue()
        let first = try MailCore(hub: hub, database: database)
        _ = await first.send("one", draft())
        let second = try MailCore(hub: hub, database: database)
        XCTAssertEqual(second.outbox.count, 1)
        XCTAssertEqual(second.outbox.first?.draft, draft())
    }

    func testRejectionStaysFailedAndIsNotRetried() async throws {
        let (core, _, one, _) = try make()
        one.sendError = MailTransportError.recipientRejected("z@example.test", 550, "no such user")
        _ = await core.send("one", draft())
        guard case .failed(let hint) = core.outbox.first?.state else { return XCTFail("expected failed") }
        XCTAssertEqual(hint.text, "mail.hint.rejected")
        let calls = one.sendCalls
        one.sendError = nil
        await core.retryOutbox()
        XCTAssertEqual(one.sendCalls, calls)
        XCTAssertEqual(core.outbox.count, 1)
    }

    func testUnreadCountPerAccount() async throws {
        let (core, _, one, two) = try make()
        one.setPage("INBOX", MailMessagePage(messages: [message("1"), message("2"), message("3", seen: true)]))
        two.setPage("INBOX", MailMessagePage(messages: [message("9")]))
        try await core.refreshFolders("one")
        try await core.refreshFolders("two")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        _ = try await core.loadPage("two", folder: "INBOX", query: nil, pageToken: nil)
        XCTAssertEqual(core.unreadCount("one"), 2)
        XCTAssertEqual(core.unreadCount("two"), 1)
        try await core.setFlags("one", messageID: "1", add: [.seen], remove: [])
        XCTAssertEqual(core.unreadCount("one"), 1)
    }

    func testSyncFinishedBringsNewMailAndRetriesOutbox() async throws {
        let (core, hub, one, _) = try make()
        var seen: [MailEngineEvent] = []
        let stream = core.events
        let collector = Task { for await event in stream { seen.append(event) } }
        defer { collector.cancel() }
        one.setPage("INBOX", MailMessagePage(messages: [message("1")]))
        hub.push(.syncFinished(.mail, "one"))
        let first = await eventually { core.lastSync("one", folder: "INBOX") != nil }
        XCTAssertTrue(first)
        XCTAssertFalse(seen.contains { if case .newMail = $0 { true } else { false } })
        one.sendError = MailTransportError.timeout
        _ = await core.send("one", draft())
        one.sendError = nil
        one.setPage("INBOX", MailMessagePage(messages: [message("2"), message("3"), message("1")]))
        hub.push(.syncFinished(.mail, "one"))
        let done = await eventually { core.outbox.isEmpty }
        XCTAssertTrue(done)
        XCTAssertTrue(seen.contains(.newMail("one", count: 2)))
        XCTAssertEqual(core.unreadCount("one"), 3)
    }

    func testSyncFailureKeepsLastStateAndReports() async throws {
        let (core, hub, one, _) = try make()
        var seen: [MailEngineEvent] = []
        let stream = core.events
        let collector = Task { for await event in stream { seen.append(event) } }
        defer { collector.cancel() }
        one.setPage("INBOX", MailMessagePage(messages: [message("1")]))
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        one.listError = MailTransportError.timeout
        hub.push(.syncFinished(.mail, "one"))
        let failed = await eventually { seen.contains { if case .syncFailed("one", _) = $0 { true } else { false } } }
        XCTAssertTrue(failed)
        XCTAssertEqual(core.messages("one", folder: "INBOX").map(\.id), ["1"])
    }
}
