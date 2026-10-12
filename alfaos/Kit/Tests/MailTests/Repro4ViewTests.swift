import Hub
@testable import Mail
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import enum MykilosServices.MailFolderRole
import XCTest

@MainActor
final class Repro4ViewTests: XCTestCase {
    private func loadedModel() async -> MailModel {
        let engine = ModelFakeEngine()
        engine.accounts = [fakeAccount("a")]
        engine.folderList["a"] = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox),
                                  MailFolder(id: "SENT", name: "Sent", role: .sent)]
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1", flags: [.flagged], attachments: 1, thread: "t"),
                                                       fakeMessage("m2", flags: [.seen])])
        let model = MailModel(engine: engine)
        await model.start()
        return model
    }

    func testViewInputForTheWordUnread() async {
        let model = await loadedModel()
        let row = model.rows[0]
        XCTAssertTrue(row.unread)
        XCTAssertEqual(row.states, [.unread, .starred, .hasAttachments])
        XCTAssertEqual(row.states.first?.key, "mail.row.unread")
        XCTAssertEqual(model.rows[1].states, [])
    }

    func testViewInputForTheUnderlineOfTheSelectedRow() async {
        let model = await loadedModel()
        XCTAssertFalse(model.rows[1].selected)
        await model.open("m2")
        XCTAssertTrue(model.rows[1].selected)
        XCTAssertEqual(model.rows[1].states, [.selected])
        XCTAssertFalse(model.rows[0].selected)
    }

    func testViewInputForTheCenterLaneTitle() async {
        let model = await loadedModel()
        await model.selectFolder("SENT")
        XCTAssertEqual(model.selectedFolder, "SENT")
        XCTAssertEqual(model.sortedFolders.first { $0.id == model.selectedFolder }?.role, .sent)
        let names = Mirror(reflecting: model).children.compactMap(\.label).filter { $0.lowercased().contains("title") }
        XCTAssertEqual(names, [])
    }
}
