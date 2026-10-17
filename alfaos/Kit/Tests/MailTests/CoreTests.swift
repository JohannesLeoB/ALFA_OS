import GRDB
import Hub
@testable import Mail
import struct MykilosKit.EmailDraft
import enum MykilosServices.GoogleGmailError
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageSummary
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

        let (gmailCore, _, gmail, _) = try make()
        gmail.sendError = GoogleGmailError.httpError(503)
        _ = await gmailCore.send("one", draft())
        let stateAfter503 = gmailCore.outbox.first?.state
        gmail.sendError = nil
        await gmailCore.retryOutbox()
        XCTAssertEqual(stateAfter503, .waiting)
        XCTAssertEqual(gmail.sent.count, 1)
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

        let html = EmailDraft(to: "z@example.test", subject: "s", body: "plain", bodyHTML: "<b>formatted</b>")
        let htmlDatabase = try DatabaseQueue()
        let htmlFirst = try MailCore(hub: hub, database: htmlDatabase)
        _ = await htmlFirst.send("one", html)
        XCTAssertEqual(htmlFirst.outbox.first?.draft.bodyHTML, "<b>formatted</b>")
        let restored = try MailCore(hub: hub, database: htmlDatabase).outbox.first?.draft.bodyHTML
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

        let (pagedCore, _, paged, _) = try make()
        paged.setTokenPage(nil, MailMessagePage(messages: (1...5).map { message("p1-\($0)") }, nextPageToken: "t"))
        paged.setTokenPage("t", MailMessagePage(messages: (1...5).map { message("p2-\($0)") }))
        try await pagedCore.refreshFolders("one")
        _ = try await pagedCore.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        _ = try await pagedCore.loadPage("one", folder: "INBOX", query: nil, pageToken: "t")
        XCTAssertEqual(pagedCore.unreadCount("one"), 10)
        _ = try await pagedCore.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        let after = pagedCore.unreadCount("one")
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

    func testGmailHttpErrorsAreClassified() {
        let hub = HubDouble()
        let unauthorized = MailFailure.classify(GoogleGmailError.httpError(401), inlet: "i", hub: hub)
        let tooMany = MailFailure.classify(GoogleGmailError.httpError(429), inlet: "i", hub: hub)
        let unavailable = MailFailure.classify(GoogleGmailError.httpError(503), inlet: "i", hub: hub)
        XCTAssertEqual(unauthorized.hint.text, Hint.signInExpiredText)
        XCTAssertTrue(tooMany.isTransient)
        XCTAssertEqual(tooMany.hint.code, "gmail.429")
        XCTAssertTrue(unavailable.isTransient)
    }

    func testSendAgainAfterARejectionLeavesTheFailedItemInTheOutbox() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = scriptedInbox
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        let id = try XCTUnwrap(model.compose(to: "z@example.test"))
        model.edit(id) { $0.subject = "s" }
        transport.sendError = MailTransportError.recipientRejected("z@example.test", 550, "no such user")
        await model.send(id)
        guard case .sendFailed(let hint) = model.draft(id)?.state else { return XCTFail("state \(String(describing: model.draft(id)?.state))") }
        XCTAssertEqual(hint.text, MailTextKey.rejected.rawValue)
        transport.sendError = nil
        await model.send(id)
        XCTAssertEqual(model.draft(id)?.state, .sent)
        XCTAssertEqual(transport.sent.count, 1)
    }

    func testDiscardingAQueuedDraftDoesNotCancelItsOutboxItem() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = scriptedInbox
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        let id = try XCTUnwrap(model.compose(to: "z@example.test"))
        model.edit(id) { $0.subject = "s" }
        transport.sendError = MailTransportError.timeout
        await model.send(id)
        XCTAssertEqual(model.draft(id)?.state, .queuedInOutbox)
        model.discard(id)
        transport.sendError = nil
        await core.retryOutbox()
        let delivered = transport.sent.count
    }

    func testOutboxItemOfARemovedAccountWaitsForever() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = scriptedInbox
        transport.setTokenPage(nil, MailMessagePage(messages: [message("1")]))
        transport.sendError = MailTransportError.timeout
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        _ = await core.send("one", draft())
        hub.remove("one")
        await core.retryOutbox()
        await core.retryOutbox()
        let item = core.outbox.first
        let rows = core.messages("one", folder: "INBOX").count
        XCTAssertEqual(item?.state, .waiting)
    }

    func testRejectedSignInIsShownAsExpiredSignIn() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.listError = MailTransportError.authenticationRejected("bad password")
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        XCTAssertEqual(model.listState, .signInExpired("one"))
    }

    func testLocalSearchMatchesTheTextAsTyped() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = scriptedInbox
        transport.setPage("INBOX", MailMessagePage(messages: [message("1", subject: "abc"), message("2", subject: "\u{C4}rger im B\u{FC}ro")]))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
    }

    func testAMailSentFromTheOutboxIsGoneAfterAReopen() async throws {
        let hub = HubDouble()
        let one = hub.add("one")
        one.sendError = MailTransportError.timeout
        let database = try DatabaseQueue()
        let first = try MailCore(hub: hub, database: database)
        _ = await first.send("one", draft())
        XCTAssertEqual(first.outbox.count, 1)
        one.sendError = nil
        await first.retryOutbox()
        XCTAssertEqual(one.sent.count, 1)
        XCTAssertTrue(first.outbox.isEmpty)
        let second = try MailCore(hub: hub, database: database)
        XCTAssertTrue(second.outbox.isEmpty)
    }

    func testLocalSearchListsTheNewestHitsFirst() async throws {
        let (core, _, one, _) = try make()
        let day: TimeInterval = 86_400
        let old = MailMessageSummary(id: "old", subject: "hit", from: "a", receivedAt: Date(timeIntervalSince1970: day))
        let new = MailMessageSummary(id: "new", subject: "hit", from: "a", receivedAt: Date(timeIntervalSince1970: 3 * day))
        let middle = MailMessageSummary(id: "middle", subject: "hit", from: "a", receivedAt: Date(timeIntervalSince1970: 2 * day))
        one.setPage("INBOX", MailMessagePage(messages: [old, new, middle]))
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        XCTAssertEqual(core.searchLocal("one", query: "hit").map(\.id), ["new", "middle", "old"])
    }
}
