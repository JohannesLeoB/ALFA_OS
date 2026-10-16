import Foundation
@testable import ShellCore
import XCTest

final class SettingsTests: XCTestCase {
    private func catalogKeys() throws -> Set<String> {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("App/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        return Set(strings.keys)
    }

    func testTheSettingsWordsAreInTheCatalogAndTheTokenSheetCarriesItsStamp() throws {
        var keys = SettingsGroup.allCases.map(\.key)
        keys += SettingsSection.allCases.map(\.key)
        keys += AppearanceChoice.allCases.map(\.key)
        keys += SettingsLabel.allCases.map(\.key)
        XCTAssertEqual(Set(keys).subtracting(try catalogKeys()).sorted(), [])
        XCTAssertEqual(Set(SettingsSection.allCases.map(\.group)), Set(SettingsGroup.allCases))
        for value in [TokenStamp.delivery, TokenStamp.deliveredAt, TokenStamp.adoptedAt, TokenStamp.state] {
            XCTAssertFalse(value.isEmpty)
        }
        XCTAssertLessThanOrEqual(TokenStamp.deliveredAt, TokenStamp.adoptedAt)
    }
}
