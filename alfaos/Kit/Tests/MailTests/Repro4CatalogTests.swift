import Foundation
import Hub
@testable import Mail
import XCTest

final class Repro4CatalogTests: XCTestCase {
    private func catalogKeys() throws -> Set<String> {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("App/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        return Set(strings.keys)
    }

    func testEveryStateOfTheMailModuleHasATextInTheCatalog() throws {
        let draftStates: [MailDraftState] = [
            .idle, .edited, .saving, .saved(Date()), .sending, .sent, .sendBlocked(.noSubject), .sendBlocked(.noRecipient),
            .sendFailed(Hint(text: "x")), .queuedInOutbox
        ]
        let listStates: [MailListState] = [
            .empty(folder: "f"), .emptySearch(query: "q", folder: "f"), .loading, .loadingMore, .noFilterMatch,
            .failed(Hint(text: "x")), .notConnected(nil), .signInExpired("i"), .offline(lastSync: nil)
        ]
        let rowStates: [MailRowState] = [.unread, .starred, .selected, .hasAttachments, .threadCount(2)]
        let cardContents: [MailCardContent] = [.bodyLoading, .conversation(2), .draftNotice]
        var keys: [String] = draftStates.map(\.key)
        keys += listStates.compactMap(\.key)
        keys += rowStates.map(\.key)
        keys += cardContents.compactMap(\.key)
        keys += [ReadingCard.remoteImagesBlockedKey, ReadingCard.quoteCollapsedKey, ReadingCard.signatureCollapsedKey,
                 ReadingCard.recipientsExpandedKey, ReadingCard.actionFailedKey]
        keys += [MailHintKey.offline, MailHintKey.signIn, MailHintKey.rejected, MailHintKey.failed]
        let catalog = try catalogKeys()
        let missing = Set(keys).subtracting(catalog).sorted()
        XCTAssertGreaterThan(keys.count, 25)
        XCTExpectFailure("BUG-4-24: the module names a text key for every state, the catalog lacks the keys of the draft, row and card states") {
            XCTAssertEqual(missing, [])
        }
    }
}
