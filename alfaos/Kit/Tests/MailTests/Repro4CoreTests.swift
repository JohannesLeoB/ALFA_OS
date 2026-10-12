import class GRDB.DatabaseQueue
import Hub
@testable import Mail
import enum MykilosServices.GoogleGmailError
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import enum MykilosServices.MailTransportError
import XCTest

@MainActor
final class Repro4CoreTests: XCTestCase {
    func testGmailHttpErrorsAreClassified() {
        let hub = Repro4Hub()
        let unauthorized = MailFailure.classify(GoogleGmailError.httpError(401), inlet: "i", hub: hub)
        let tooMany = MailFailure.classify(GoogleGmailError.httpError(429), inlet: "i", hub: hub)
        let unavailable = MailFailure.classify(GoogleGmailError.httpError(503), inlet: "i", hub: hub)
        XCTAssertEqual(unauthorized.hint.text, MailHintKey.signIn)
        XCTAssertTrue(tooMany.isTransient)
        XCTAssertEqual(tooMany.hint.code, "gmail.429")
        XCTAssertTrue(unavailable.isTransient)
    }

    func testGmailHttpErrorOnSendFailsTheOutboxItemForGood() async throws {
        let hub = Repro4Hub()
        let transport = hub.add("one")
        transport.sendError = GoogleGmailError.httpError(503)
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        _ = await core.send("one", draft())
        let state = core.outbox.first?.state
        transport.sendError = nil
        await core.retryOutbox()
        let sent = transport.sent.count
        XCTAssertEqual(state, .waiting)
        XCTAssertEqual(sent, 1)
    }

    func testInboxUnreadCountFallsWhenASyncReplacesTheLoadedPages() async throws {
        let hub = Repro4Hub()
        let transport = hub.add("one")
        transport.folders = repro4Inbox
        transport.setPage(nil, MailMessagePage(messages: (1...5).map { message("p1-\($0)") }, nextPageToken: "t"))
        transport.setPage("t", MailMessagePage(messages: (1...5).map { message("p2-\($0)") }))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: "t")
        XCTAssertEqual(core.unreadCount("one"), 10)
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        let after = core.unreadCount("one")
        XCTExpectFailure("BUG-4-07: unreadCount counts only the mirrored rows, so it drops from 10 to 5 when a sync replaces the mirror, although no mail was read") {
            XCTAssertEqual(after, 10)
        }
    }

    func testSendAgainAfterARejectionLeavesTheFailedItemInTheOutbox() async throws {
        let hub = Repro4Hub()
        let transport = hub.add("one")
        transport.folders = repro4Inbox
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        let id = try XCTUnwrap(model.compose(to: "z@example.test"))
        model.edit(id) { $0.subject = "s" }
        transport.sendError = MailTransportError.recipientRejected("z@example.test", 550, "no such user")
        await model.send(id)
        guard case .sendFailed(let hint) = model.draft(id)?.state else { return XCTFail("state \(String(describing: model.draft(id)?.state))") }
        XCTAssertEqual(hint.text, MailHintKey.rejected)
        transport.sendError = nil
        await model.send(id)
        XCTAssertEqual(model.draft(id)?.state, .sent)
        XCTAssertEqual(transport.sent.count, 1)
        let leftover = core.outbox.count
        XCTExpectFailure("BUG-4-08: the failed outbox item stays after the same draft was sent again, and no engine function removes it") {
            XCTAssertEqual(leftover, 0)
        }
    }

    func testDiscardingAQueuedDraftDoesNotCancelItsOutboxItem() async throws {
        let hub = Repro4Hub()
        let transport = hub.add("one")
        transport.folders = repro4Inbox
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
        XCTExpectFailure("BUG-4-09: discard removes the card, the mail is still sent by the next retry") {
            XCTAssertEqual(delivered, 0)
        }
    }

    func testOutboxItemOfARemovedAccountWaitsForever() async throws {
        let hub = Repro4Hub()
        let transport = hub.add("one")
        transport.folders = repro4Inbox
        transport.setPage(nil, MailMessagePage(messages: [message("1")]))
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
        XCTExpectFailure("BUG-4-10: after the account is removed its outbox item stays waiting and is counted up on every retry, and its mirrored mail stays in the database") {
            XCTAssertNotEqual(item?.state, .waiting)
            XCTAssertEqual(rows, 0)
        }
    }

    func testRejectedSignInIsShownAsAFailureNotAsExpiredSignIn() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.listError = MailTransportError.authenticationRejected("bad password")
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        let state = model.listState
        guard case .failed(let hint) = state else { return XCTFail("state \(state)") }
        XCTAssertEqual(hint.text, MailHintKey.signIn)
        XCTExpectFailure("BUG-4-11: a rejected sign-in gives the hint mail.hint.signIn, the model only knows hint.signin.expired, so signInExpired is only reached through the inlet state") {
            XCTAssertEqual(state, .signInExpired("one"))
        }
    }

    func testLocalSearchTreatsUnderscoreAsWildcard() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = repro4Inbox
        transport.setPage("INBOX", MailMessagePage(messages: [message("1", subject: "abc")]))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        let hits = core.searchLocal("one", query: "a_c").map(\.id)
        XCTExpectFailure("BUG-4-12: the query goes into LIKE unescaped, so _ matches any character") {
            XCTAssertEqual(hits, [])
        }
    }

    func testLocalSearchIsNotCaseInsensitiveForUmlauts() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = repro4Inbox
        transport.setPage("INBOX", MailMessagePage(messages: [message("1", subject: "Ärger im Büro")]))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        let hits = core.searchLocal("one", query: "ärger").map(\.id)
        XCTExpectFailure("BUG-4-13: SQLite LIKE folds case for ASCII only, so a lowercase umlaut does not find the capital one") {
            XCTAssertEqual(hits, ["1"])
        }
    }
}
