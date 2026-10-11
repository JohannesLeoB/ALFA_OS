import XCTest
@testable import StudioCore

private final class FakeKeychain: KeychainAccessing, @unchecked Sendable {
    let namespace = KeychainNamespace(bundleIdentifier: "test.studio", appName: "Studio")
    var content: [String: String] = [:]
    func load(service: String, account: String) throws -> String? { content["\(service)|\(account)"] }
    @discardableResult
    func store(_ value: String, service: String, account: String) throws -> Bool {
        content["\(service)|\(account)"] = value; return true
    }
}

final class KeychainPreviousIdentityTests: XCTestCase {
    override func tearDown() { CurrentUserContext.resetForTesting(); super.tearDown() }

    func testAccessStoredUnderThePreviousUserIdIsFoundAndMovedAlong() throws {
        CurrentUserContext.set("first-id")
        CurrentUserContext.set("second-id")
        XCTAssertEqual(CurrentUserContext.previous, "first-id")

        let cabinet = FakeKeychain()
        let old = PerUserKeychainService.perUser("konkaapps", userID: "first-id", namespace: cabinet.namespace)
        try cabinet.store("value", service: old, account: "basicAuth")

        let found = try PerUserKeychainMigrator.loadWithMigration(
            keychain: cabinet, base: "konkaapps", userID: "second-id", account: "basicAuth")
        XCTAssertEqual(found, "value", "the access under the old id is not found")

        let new = PerUserKeychainService.perUser("konkaapps", userID: "second-id", namespace: cabinet.namespace)
        XCTAssertEqual(cabinet.content["\(new)|basicAuth"], "value", "it moves along when found")
    }

    func testWithoutAPreviousIdNothingIsInvented() throws {
        CurrentUserContext.set("only-one")
        let cabinet = FakeKeychain()
        let found = try PerUserKeychainMigrator.loadWithMigration(
            keychain: cabinet, base: "konkaapps", userID: "only-one", account: "basicAuth")
        XCTAssertNil(found)
    }
}
