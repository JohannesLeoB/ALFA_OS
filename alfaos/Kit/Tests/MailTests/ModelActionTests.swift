import Foundation
import Hub
@testable import Mail
import struct MykilosKit.EmailDraft
import struct MykilosServices.MailAttachmentInfo
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessageBody
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailStoredDraft
import XCTest

@MainActor
final class ModelActionTests: XCTestCase {
    private let fixed = Date(timeIntervalSince1970: 5_000)

    private func make(folders: [MailFolder]? = nil) async -> (MailModel, ModelFakeEngine) {
        let engine = ModelFakeEngine()
        engine.accounts = [fakeAccount("a")]
        engine.folderList["a"] = folders ?? [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1"), fakeMessage("m2", flags: [.seen])])
        let fixed = fixed
        let model = MailModel(engine: engine, clock: { fixed })
        await model.start()
        return (model, engine)
    }

    private func stepArchiveRemovesTheRowClosesTheCardAndCountsAgain() async {
        let (model, engine) = await make()
        await model.open("m1")
        engine.unread["a"] = 7
        await model.archive("m1")
        XCTAssertEqual(engine.actionCalls, ["archive:m1"])
        XCTAssertEqual(model.summaries.map(\.id), ["m2"])
        XCTAssertTrue(model.cards.isEmpty)
        XCTAssertNil(model.selectedMessage)
        XCTAssertEqual(model.unread["a"], 7)
        XCTAssertNil(model.actionFailure(for: "m1"))
    }

    private func stepArchiveInTheAllFolderKeepsTheRowListed() async {
        let all = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox), MailFolder(id: "ALL", name: "All", role: .all)]
        let (model, engine) = await make(folders: all)
        await model.selectFolder("ALL")
        await model.archive("m1")
        XCTAssertEqual(engine.actionCalls, ["archive:m1"])
        XCTAssertEqual(model.summaries.map(\.id), ["m1", "m2"])
    }

    private func stepTrashSpamAndMoveEachAskTheEngineAndDropTheRow() async {
        let (model, engine) = await make()
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1"), fakeMessage("m2"), fakeMessage("m3")])
        await model.loadSelection()
        await model.trash("m1")
        await model.markSpam("m2")
        await model.move("m3", toFolder: "WORK")
        XCTAssertEqual(engine.actionCalls, ["trash:m1", "spam:m2", "move:m3>WORK"])
        XCTAssertTrue(model.summaries.isEmpty)
    }

    private func stepARefusedActionKeepsTheRowAndTheCardAndShowsTheHint() async {
        let (model, engine) = await make()
        await model.open("m1")
        engine.actionError = .provider(Hint(text: "mail.hint.rejected", detail: "NO read only"))
        await model.trash("m1")
        XCTAssertEqual(model.actionFailure(for: "m1"), Hint(text: "mail.hint.rejected", detail: "NO read only"))
        XCTAssertEqual(model.summaries.map(\.id), ["m1", "m2"])
        XCTAssertEqual(model.cards.map(\.id), ["m1"])
        engine.actionError = nil
        await model.trash("m1")
        XCTAssertNil(model.actionFailure(for: "m1"))
    }

    private func stepTheCardListsTheAttachmentsOfItsBodyAndLoadsOneOnDemand() async {
        let (model, engine) = await make()
        let info = MailAttachmentInfo(id: "a1", filename: "plan.pdf", mimeType: "application/pdf", sizeBytes: 3)
        engine.bodies["m1"] = MailMessageBody(text: "hi", attachments: [info])
        engine.attachmentData = Data("pdf".utf8)
        await model.open("m1")
        XCTAssertEqual(model.cards.first?.attachments, [info])
        let data = await model.attachmentData("m1", attachmentID: "a1")
        XCTAssertEqual(data, Data("pdf".utf8))
        XCTAssertEqual(engine.actionCalls, ["attachment:m1/a1"])
    }

    private func stepAFailedAttachmentDownloadGivesNoDataButAHint() async {
        let (model, engine) = await make()
        engine.actionError = .provider(Hint(text: "mail.hint.failed"))
        let data = await model.attachmentData("m1", attachmentID: "a1")
        XCTAssertNil(data)
        XCTAssertEqual(model.actionFailure(for: "m1"), Hint(text: "mail.hint.failed"))
    }

    private func stepTheConversationOfACardComesFromItsThread() async {
        let (model, engine) = await make()
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1", thread: "t9"), fakeMessage("m2")])
        await model.loadSelection()
        engine.threadMessages = [fakeMessage("m0", thread: "t9"), fakeMessage("m1", thread: "t9")]
        await model.open("m1")
        await model.open("m2")
        await model.loadThread("m1")
        XCTAssertEqual(model.cards.first { $0.id == "m1" }?.conversation.map(\.id), ["m0", "m1"])
        XCTAssertEqual(model.cards.first { $0.id == "m2" }?.conversation, [])
        await model.loadThread("m2")
        XCTAssertEqual(engine.actionCalls, ["thread:m1/t9", "thread:m2/m2"])
    }

    private func stepAFailedThreadLoadLeavesTheCardAloneAndShowsTheHint() async {
        let (model, engine) = await make()
        await model.open("m1")
        engine.actionError = .provider(Hint(text: "mail.hint.failed"))
        await model.loadThread("m1")
        XCTAssertEqual(model.actionFailure(for: "m1"), Hint(text: "mail.hint.failed"))
        XCTAssertEqual(model.cards.first?.conversation, [])
    }

    private func newDraft(_ model: MailModel) -> UUID {
        let id = model.compose(to: "z@example.test")!
        model.edit(id) { $0.subject = "Plan" }
        return id
    }

    private func stepSavingWalksFromEditedThroughSavingToSavedWithTheTimeAndKeepsTheServerID() async {
        let (model, engine) = await make()
        let id = newDraft(model)
        XCTAssertEqual(model.draft(id)?.state, .edited)
        engine.holdSave = true
        let task = Task { await model.save(id) }
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(model.draft(id)?.state, .saving)
        engine.holdSave = false
        engine.release()
        await task.value
        XCTAssertEqual(model.draft(id)?.state, .saved(fixed))
        XCTAssertEqual(model.draft(id)?.remoteID, "remote-1")
        engine.savedDraftID = "remote-2"
        model.edit(id) { $0.body = "more" }
        await model.save(id)
        XCTAssertEqual(engine.savedDrafts.map(\.replacing), [nil, "remote-1"])
        XCTAssertEqual(model.draft(id)?.remoteID, "remote-2")
    }

    private func stepAnEditWhileSavingKeepsTheDraftEditedSoTheNewTextIsSavedAgain() async {
        let (model, engine) = await make()
        let id = newDraft(model)
        engine.holdSave = true
        let task = Task { await model.save(id) }
        await Task.yield()
        await Task.yield()
        model.edit(id) { $0.body = "typed while saving" }
        engine.holdSave = false
        engine.release()
        await task.value
        XCTAssertEqual(model.draft(id)?.state, .edited)
        XCTAssertEqual(model.draft(id)?.remoteID, "remote-1")
    }

    private func stepAFailedSaveReturnsToEditedAndNamesTheFailure() async {
        let (model, engine) = await make()
        let id = newDraft(model)
        engine.actionError = .provider(Hint(text: "mail.hint.offline"))
        await model.save(id)
        XCTAssertEqual(model.draft(id)?.state, .edited)
        XCTAssertEqual(model.draft(id)?.saveFailure, Hint(text: "mail.hint.offline"))
        XCTAssertNil(model.draft(id)?.remoteID)
        engine.actionError = nil
        await model.save(id)
        XCTAssertNil(model.draft(id)?.saveFailure)
        XCTAssertEqual(model.draft(id)?.state, .saved(fixed))
    }

    private func stepDiscardingASavedDraftDeletesItOnTheServerAndAnUnsavedOneJustGoes() async {
        let (model, engine) = await make()
        let saved = newDraft(model)
        await model.save(saved)
        let unsaved = newDraft(model)
        await model.deleteDraft(unsaved)
        XCTAssertNil(model.draft(unsaved))
        XCTAssertFalse(engine.actionCalls.contains { $0.hasPrefix("deleteDraft") })
        await model.deleteDraft(saved)
        XCTAssertNil(model.draft(saved))
        XCTAssertEqual(engine.actionCalls.last, "deleteDraft:remote-1")
    }

    private func stepADraftThatCannotBeDeletedOnTheServerStaysWithTheFailure() async {
        let (model, engine) = await make()
        let id = newDraft(model)
        await model.save(id)
        engine.actionError = .provider(Hint(text: "mail.hint.failed"))
        await model.deleteDraft(id)
        XCTAssertNotNil(model.draft(id))
        XCTAssertEqual(model.draft(id)?.saveFailure, Hint(text: "mail.hint.failed"))
    }

    private func stepSendingASavedDraftGoesThroughTheDraftAndAnUnsavedOneThroughPlainSend() async {
        let (model, engine) = await make()
        let saved = newDraft(model)
        await model.save(saved)
        await model.send(saved)
        XCTAssertEqual(engine.sentFromDraft.map(\.id), ["remote-1"])
        XCTAssertEqual(engine.sentFromDraft.first?.draft.subject, "Plan")
        XCTAssertTrue(engine.sentDrafts.isEmpty)
        XCTAssertEqual(model.draft(saved)?.state, .sent)
        let plain = newDraft(model)
        await model.send(plain)
        XCTAssertEqual(engine.sentDrafts.count, 1)
        XCTAssertEqual(engine.sentFromDraft.count, 1)
    }

    private func stepOpeningAStoredDraftMakesACardLinkedToTheServerDraftOnlyOnce() async {
        let (model, engine) = await make()
        engine.storedDraft = MailStoredDraft(id: "d7", draft: EmailDraft(to: "a@x.test", subject: "Stored", body: "text"))
        let first = await model.editDraft("m1")
        let second = await model.editDraft("m1")
        XCTAssertEqual(first, second)
        XCTAssertEqual(model.drafts.count, 1)
        XCTAssertEqual(model.draft(first!)?.remoteID, "d7")
        XCTAssertEqual(model.draft(first!)?.draft.subject, "Stored")
        XCTAssertEqual(model.draft(first!)?.state, .idle)
    }

    private func stepAStoredDraftThatCannotBeLoadedMakesNoCardAndShowsTheHint() async {
        let (model, engine) = await make()
        engine.actionError = .provider(Hint(text: "mail.hint.failed"))
        let id = await model.editDraft("m1")
        XCTAssertNil(id)
        XCTAssertTrue(model.drafts.isEmpty)
        XCTAssertEqual(model.actionFailure(for: "m1"), Hint(text: "mail.hint.failed"))
    }

    func testTheModelActions() async throws {
        await stepArchiveRemovesTheRowClosesTheCardAndCountsAgain()
        await stepArchiveInTheAllFolderKeepsTheRowListed()
        await stepTrashSpamAndMoveEachAskTheEngineAndDropTheRow()
        await stepARefusedActionKeepsTheRowAndTheCardAndShowsTheHint()
        await stepTheCardListsTheAttachmentsOfItsBodyAndLoadsOneOnDemand()
        await stepAFailedAttachmentDownloadGivesNoDataButAHint()
        await stepTheConversationOfACardComesFromItsThread()
        await stepAFailedThreadLoadLeavesTheCardAloneAndShowsTheHint()
        await stepSavingWalksFromEditedThroughSavingToSavedWithTheTimeAndKeepsTheServerID()
        await stepAnEditWhileSavingKeepsTheDraftEditedSoTheNewTextIsSavedAgain()
        await stepAFailedSaveReturnsToEditedAndNamesTheFailure()
        await stepDiscardingASavedDraftDeletesItOnTheServerAndAnUnsavedOneJustGoes()
        await stepADraftThatCannotBeDeletedOnTheServerStaysWithTheFailure()
        await stepSendingASavedDraftGoesThroughTheDraftAndAnUnsavedOneThroughPlainSend()
        await stepOpeningAStoredDraftMakesACardLinkedToTheServerDraftOnlyOnce()
        await stepAStoredDraftThatCannotBeLoadedMakesNoCardAndShowsTheHint()
    }
}
