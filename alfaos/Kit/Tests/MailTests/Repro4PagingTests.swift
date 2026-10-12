import class GRDB.DatabaseQueue
import Hub
@testable import Mail
import enum MykilosServices.GoogleGmailError
import struct MykilosServices.GoogleAPIFault
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import XCTest

@MainActor
final class Repro4PagingTests: XCTestCase {
    private func engineWithTwoAccounts() -> Repro4Engine {
        let engine = Repro4Engine()
        engine.accounts = [fakeAccount("a"), fakeAccount("b")]
        engine.folderList = ["a": repro4Inbox, "b": repro4Inbox]
        engine.pages[Repro4Engine.key("a", "INBOX", nil)] =
            MailMessagePage(messages: [fakeMessage("a1")], nextPageToken: "token-of-a")
        engine.pages[Repro4Engine.key("b", "INBOX", nil)] = MailMessagePage(messages: [fakeMessage("b1")])
        return engine
    }

    func testRemovingTheSelectedAccountLetsLoadMoreUseTheTokenOfTheOldOne() async {
        let engine = engineWithTwoAccounts()
        let model = MailModel(engine: engine)
        await model.start()
        XCTAssertEqual(model.selectedInlet, "a")
        XCTAssertEqual(model.nextPageToken, "token-of-a")
        engine.accounts = [fakeAccount("b")]
        await model.handle(.accountsChanged)
        XCTAssertEqual(model.selectedInlet, "b")
        engine.pageCalls = []
        await model.loadMore()
        let calls = engine.pageCalls
        XCTAssertFalse(calls.contains { $0.hasSuffix("|token-of-a") }, "calls \(calls)")
    }

    func testRemovingTheOnlyAccountStillListsItsRows() async {
        let engine = engineWithTwoAccounts()
        engine.accounts = [fakeAccount("a")]
        let model = MailModel(engine: engine)
        await model.start()
        XCTAssertEqual(model.rows.map(\.id), ["a1"])
        engine.accounts = []
        await model.handle(.accountsChanged)
        XCTAssertNil(model.selectedInlet)
        let rows = model.rows.map(\.id)
        let listState = model.listState
        XCTAssertEqual(listState, .notConnected(nil))
        XCTAssertEqual(rows, [])
        XCTAssertNil(model.nextPageToken)
        XCTAssertTrue(model.folders.isEmpty)
    }

    func testLoadMoreOfTheOldAccountLandsInTheNewAccountWhileItsFoldersLoad() async {
        let engine = engineWithTwoAccounts()
        engine.folderList["b"] = []
        engine.pendingFolders["b"] = repro4Inbox
        engine.pages[Repro4Engine.key("a", "INBOX", "token-of-a")] =
            MailMessagePage(messages: [fakeMessage("a2")], nextPageToken: "token-of-a-2")
        let moreGate = Repro4Gate()
        engine.pageGates[Repro4Engine.key("a", "INBOX", "token-of-a")] = moreGate
        let folderGate = Repro4Gate()
        engine.folderGates["b"] = folderGate
        let model = MailModel(engine: engine)
        await model.start()
        let more = Task { await model.loadMore() }
        let waitingMore = await eventually { moreGate.hasWaiter }
        XCTAssertTrue(waitingMore)
        let switching = Task { await model.selectAccount("b") }
        let waitingFolders = await eventually { folderGate.hasWaiter }
        XCTAssertTrue(waitingFolders)
        moreGate.release()
        await more.value
        let rows = model.summaries.map(\.id)
        let token = model.nextPageToken
        let inlet = model.selectedInlet
        folderGate.release()
        await switching.value
        XCTAssertEqual(inlet, "b")
        XCTExpectFailure("BUG-4-05: a loadMore of account a that finishes while account b fetches its folders is accepted into b's list and token, because the generation is only raised after the folders arrive") {
            XCTAssertEqual(rows, [])
            XCTAssertNil(token)
        }
    }

    func testOneRejectedLoadMoreEndsPagingUntilTheFolderIsSelectedAgain() async throws {
        let hub = Repro4Hub()
        let transport = hub.add("two")
        transport.folders = repro4Inbox
        transport.setPage(nil, MailMessagePage(messages: [message("1")], nextPageToken: "t1"))
        transport.setPage("t1", MailMessagePage(messages: [message("9")]))
        transport.failList(call: 2, GoogleGmailError.api(GoogleAPIFault(status: 403, reason: "rateLimitExceeded")))
        let model = MailModel(engine: try MailCore(hub: hub, database: DatabaseQueue()))
        await model.start()
        XCTAssertTrue(model.canLoadMore)
        await model.loadMore()
        let afterFailure = model.canLoadMore
        let stateAfterFailure = model.listState
        await model.loadMore()
        let ids = model.summaries.map(\.id)
        guard case .offline = stateAfterFailure else { return XCTFail("state \(stateAfterFailure)") }
        XCTAssertTrue(afterFailure)
        XCTAssertEqual(ids, ["1", "9"])
    }

    func testRowsRemovedOnTheServerStayInTheListAfterASync() async throws {
        let hub = Repro4Hub()
        let transport = hub.add("one")
        transport.folders = repro4Inbox
        transport.setPage(nil, MailMessagePage(messages: [message("1"), message("2")]))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        XCTAssertEqual(model.summaries.map(\.id), ["1", "2"])
        transport.setPage(nil, MailMessagePage(messages: [message("2")]))
        hub.push(.syncFinished(.mail, "one"))
        let mirrored = await eventually { core.messages("one", folder: "INBOX").map(\.id) == ["2"] }
        XCTAssertTrue(mirrored)
        try? await Task.sleep(for: .milliseconds(100))
        let ids = model.summaries.map(\.id)
        XCTExpectFailure("BUG-4-06: mergeMirror never removes rows, so a mail that left the mirror stays in the list") {
            XCTAssertEqual(ids, ["2"])
        }
    }
}
