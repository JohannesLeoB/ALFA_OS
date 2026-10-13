import Foundation
import Hub
@testable import Mail
import XCTest

final class CatalogTests: XCTestCase {
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
        var keys: [String] = MailDraftState.Kind.allCases.map(\.key)
        keys += MailListState.Kind.allCases.compactMap(\.key)
        keys += MailRowState.Kind.allCases.map(\.key)
        keys += MailCardContent.Kind.allCases.compactMap(\.key)
        keys += MailTextKey.allCases.map(\.rawValue)
        keys.append(Hint.signInExpiredText)
        let missing = Set(keys).subtracting(try catalogKeys()).sorted()
        XCTAssertEqual(missing, [], "BUG-4-24")
    }
}
