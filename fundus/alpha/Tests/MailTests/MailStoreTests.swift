import XCTest
@testable import AlfaServices
import AlfaKit

final class MailStoreTests: XCTestCase {
    func testMigrationUpsertFilterAndSearch() throws {
        let db = try GRDBDatabase.inMemory()
        let store = MailStore(db: db)
        let konto = "test@example.com"
        let a = GoogleGmailMessage(id: "a", threadID: "t1", subject: "Küchenplanung Beispiel", from: "Person A",
                                   fromRaw: "Person A <a@example.com>", snippet: "Hallo, wir hätten gern ein Angebot",
                                   receivedAt: Date(timeIntervalSince1970: 200), labels: ["INBOX", "UNREAD"])
        let b = GoogleGmailMessage(id: "b", threadID: "t2", subject: "Rechnung 4711", from: "Buchhaltung",
                                   snippet: "Anbei die Rechnung", receivedAt: Date(timeIntervalSince1970: 100),
                                   labels: ["SENT"])
        let c = GoogleGmailMessage(id: "c", threadID: "t3", subject: "Alt", from: "Archiv",
                                   snippet: "archiviert", receivedAt: Date(timeIntervalSince1970: 50), labels: [])
        store.upsert([a, b, c], account: konto)

        XCTAssertEqual(store.count(account: konto), 3)
        XCTAssertEqual(store.messages(account: konto, filter: .label("INBOX")).map(\.id), ["a"])
        XCTAssertEqual(store.messages(account: konto, filter: .archive).map(\.id), ["c"])
        XCTAssertEqual(store.messages(account: konto, filter: .all).map(\.id), ["a", "b", "c"])
        XCTAssertEqual(store.unreadCount(account: konto), 1)
        XCTAssertEqual(store.search(account: konto, text: "Küchen").map(\.id), ["a"])
        XCTAssertEqual(store.search(account: konto, text: "rechnung").map(\.id), ["b"])

        store.saveBody(GmailMailBody(text: "Volltext", html: "<p>Volltext</p>", inlineImages: ["cid1": "att1"]), for: "a")
        XCTAssertEqual(store.body(for: "a")?.html, "<p>Volltext</p>")
        XCTAssertEqual(store.body(for: "a")?.inlineImages["cid1"], "att1")
        XCTAssertEqual(store.search(account: konto, text: "Volltext").map(\.id), ["a"])

        store.upsert([GoogleGmailMessage(id: "a", threadID: "t1", subject: "Küchenplanung Beispiel", from: "Person A",
                                         snippet: "x", receivedAt: Date(timeIntervalSince1970: 200), labels: ["INBOX"])], account: konto)
        XCTAssertEqual(store.body(for: "a")?.text, "Volltext")
        XCTAssertEqual(store.unreadCount(account: konto), 0)

        store.setLabels(["INBOX", "STARRED"], for: "a")
        XCTAssertEqual(store.messages(account: konto, filter: .label("STARRED")).map(\.id), ["a"])
        store.delete(ids: ["b"])
        XCTAssertEqual(store.count(account: konto), 2)

        XCTAssertNil(store.historyId(account: konto))
        store.setHistoryId("12345", account: konto)
        XCTAssertEqual(store.historyId(account: konto), "12345")
    }
}
