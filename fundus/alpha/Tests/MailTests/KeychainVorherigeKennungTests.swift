import XCTest
@testable import MykilosServices

private final class Attrappe: KeychainAccessing, @unchecked Sendable {
    var content: [String: String] = [:]
    func load(service: String, account: String) throws -> String? { content["\(service)|\(account)"] }
    @discardableResult
    func store(_ value: String, service: String, account: String) throws -> Bool {
        content["\(service)|\(account)"] = value; return true
    }
}

final class KeychainVorherigeKennungTests: XCTestCase {
    override func tearDown() { CurrentUserContext.resetForTesting(); super.tearDown() }

    func testAccessStoredUnderThePreviousUserIdIsFoundAndMovedAlong() throws {
        CurrentUserContext.set("erste-kennung")
        CurrentUserContext.set("zweite-kennung")
        XCTAssertEqual(CurrentUserContext.vorherige, "erste-kennung")

        let schrank = Attrappe()
        let alt = PerUserKeychainService.perUser("konkaapps", userID: "erste-kennung")
        try schrank.store("wert", service: alt, account: "basicAuth")

        let gefunden = try PerUserKeychainMigrator.loadWithMigration(
            keychain: schrank, base: "konkaapps", userID: "zweite-kennung", account: "basicAuth")
        XCTAssertEqual(gefunden, "wert", "der Zugang unter der alten Kennung wird nicht gefunden")

        let neu = PerUserKeychainService.perUser("konkaapps", userID: "zweite-kennung")
        XCTAssertEqual(schrank.content["\(neu)|basicAuth"], "wert", "er zieht beim Fund mit um")
    }

    func testWithoutAPreviousIdNothingIsInvented() throws {
        CurrentUserContext.set("nur-eine")
        let schrank = Attrappe()
        let gefunden = try PerUserKeychainMigrator.loadWithMigration(
            keychain: schrank, base: "konkaapps", userID: "nur-eine", account: "basicAuth")
        XCTAssertNil(gefunden)
    }
}
