import Hub
import Mail
import struct MykilosKit.EmailDraft
import struct MykilosKit.MailSignatureContact
import enum MykilosServices.MailFolderRole
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import XCTest

@MainActor
final class ModelTests: XCTestCase {
    func makeModel(_ engine: ModelFakeEngine, state: InletState = .connected(probed: Date())) -> MailModel {
        engine.accounts = [fakeAccount("a", state: state)]
        engine.folderList["a"] = [MailFolder(id: "SENT", name: "Sent", role: .sent),
                                  MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        return MailModel(engine: engine)
    }

    func testListEmptyLoadingLoadedFailed() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [])
        await model.start()
        XCTAssertEqual(model.selectedFolder, "INBOX")
        XCTAssertEqual(model.listState, .empty(folder: "INBOX"))

        engine.holdPages = true
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")])
        let task = Task { await model.loadSelection() }
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(model.listState, .loading)
        engine.holdPages = false
        engine.release()
        await task.value
        XCTAssertEqual(model.listState, .loaded)

        engine.pageError = .provider(Hint(text: "hint.x"))
        await model.loadSelection()
        XCTAssertEqual(model.listState, .failed(Hint(text: "hint.x")))
    }

    func testSearchWithoutHitsIsEmptySearch() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        await model.start()
        await model.search("zzz")
        XCTAssertEqual(model.listState, .emptySearch(query: "zzz", folder: "INBOX"))
    }

    func testFilterWithoutHitsIsNoFilterMatch() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1", flags: [.seen])])
        await model.start()
        model.setFilter(.unread)
        XCTAssertEqual(model.listState, .noFilterMatch)
        model.setFilter(.all)
        XCTAssertEqual(model.listState, .loaded)
    }

    func testLoadMoreAppendsByPageToken() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")], nextPageToken: "t2")
        engine.pages["t2"] = MailMessagePage(messages: [fakeMessage("m2")])
        await model.start()
        XCTAssertTrue(model.canLoadMore)
        await model.loadMore()
        XCTAssertEqual(model.summaries.map(\.id), ["m1", "m2"])
        XCTAssertFalse(model.canLoadMore)
    }

    func testSendWithoutSubjectIsBlocked() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        await model.start()
        let id = model.compose(to: "z@x.test")!
        await model.send(id)
        XCTAssertEqual(model.draft(id)?.state, .sendBlocked(.noSubject))
        model.edit(id) { $0.subject = "s" ; $0.to = nil }
        await model.send(id)
        XCTAssertEqual(model.draft(id)?.state, .sendBlocked(.noRecipient))
        XCTAssertTrue(engine.sentDrafts.isEmpty)
    }

    func testSendQueuedIsQueuedInOutbox() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        await model.start()
        let draft = EmailDraft(to: "z@x.test", subject: "s", body: "b")
        let item = OutboxItem(inlet: "a", draft: draft)
        engine.outbox = [item]
        engine.sendOutcome = .queued(item.id)
        let id = model.compose(to: "z@x.test")!
        model.edit(id) { $0.subject = "s" }
        await model.send(id)
        XCTAssertEqual(model.draft(id)?.state, .queuedInOutbox)
        engine.outbox = []
        await model.handle(.outboxChanged)
        XCTAssertEqual(model.draft(id)?.state, .sent)
    }

    func testSendSent() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        await model.start()
        let id = model.compose(to: "z@x.test")!
        model.edit(id) { $0.subject = "s" }
        await model.send(id)
        XCTAssertEqual(model.draft(id)?.state, .sent)
    }

    func testUnreadPerAccountAndTotal() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.accounts.append(fakeAccount("b"))
        engine.unread = ["a": 3, "b": 4]
        await model.start()
        XCTAssertEqual(model.unread, ["a": 3, "b": 4])
        XCTAssertEqual(model.totalUnread, 7)
        engine.unread["a"] = 5
        await model.handle(.newMail("a", count: 2))
        XCTAssertEqual(model.totalUnread, 9)
    }

    func testSignInExpiredFromAccountState() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine, state: .failed(Hint(text: "hint.signin.expired")))
        await model.start()
        XCTAssertEqual(model.listState, .signInExpired("a"))
    }

    func testNotConnectedFromAccountState() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine, state: .created)
        await model.start()
        XCTAssertEqual(model.listState, .notConnected("a"))
    }

    func testContactFromSignatureYieldsCommand() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")])
        engine.bodies["m1"] = .init(text: "Hi\n\n--\nAnna Berg\nBerg GmbH\nTel +49 30 1234567\n")
        await model.start()
        await model.contactFromSignature("m1")
        var iterator = model.commands.makeAsyncIterator()
        let command = await iterator.next()
        guard case .contactFromSignature(let ref, let contact) = command else { return XCTFail("no command") }
        XCTAssertEqual(ref, MailMessageRef(inlet: "a", messageID: "m1"))
        XCTAssertEqual(contact.name, "Anna Berg")
        XCTAssertEqual(contact.organisation, "Berg GmbH")
    }

    func testCardLimitDropsOldest() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: (1...12).map { fakeMessage("m\($0)", flags: [.seen]) })
        await model.start()
        XCTAssertEqual(model.cardLimit, 10)
        for index in 1...12 { await model.open("m\(index)") }
        XCTAssertEqual(model.cards.count, 10)
        XCTAssertEqual(model.cards.first?.id, "m3")
        model.setCardLimit(2)
        XCTAssertEqual(model.cards.map(\.id), ["m11", "m12"])
    }

    func testOpenMarksReadAndFlagFailureKeepsHint() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")])
        engine.unread = ["a": 1]
        await model.start()
        await model.open("m1")
        XCTAssertEqual(engine.flagCalls.first?.1, [.seen])
        XCTAssertEqual(model.rows.first?.unread, false)
        engine.flagError = .provider(Hint(text: "hint.f"))
        await model.setStarred("m1", true)
        XCTAssertEqual(model.actionFailure(for: "m1"), Hint(text: "hint.f"))
        XCTAssertEqual(model.rows.first?.starred, false)
    }

    func testReplyAllBuildsDraft() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1", thread: "th", subject: "Hello")])
        await model.start()
        let id = await model.reply(to: "m1", all: true)!
        let draft = model.draft(id)!.draft
        XCTAssertEqual(draft.subject, "Re: Hello")
        XCTAssertEqual(draft.to, "Anna Berg <anna@x.test>")
        XCTAssertEqual(draft.cc, "bob@x.test, carl@x.test")
        XCTAssertEqual(draft.inReplyTo, "m1")
        XCTAssertEqual(draft.threadID, "th")
        XCTAssertTrue(draft.body.contains("> text of m1"))
        let forward = await model.forward("m1")!
        XCTAssertEqual(model.draft(forward)?.draft.subject, "Fwd: Hello")
        XCTAssertTrue(model.draft(forward)!.draft.attachments.isEmpty)
    }

    func testOfflineKeepsLastSync() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pageError = .provider(Hint(text: MailHintKey.offline))
        await model.start()
        XCTAssertEqual(model.listState, .offline(lastSync: Date(timeIntervalSince1970: 100)))
    }

    func testRowStatesAndThreadCount() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [
            fakeMessage("m1", flags: [.flagged], attachments: 1, thread: "t"), fakeMessage("m2", thread: "t")])
        await model.start()
        XCTAssertEqual(model.rows[0].states, [.unread, .starred, .hasAttachments, .threadCount(2)])
        XCTAssertEqual(model.rows[1].states, [.unread, .threadCount(2)])
    }
}
