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

final class KeychainNamensraumTests: XCTestCase {
    override func tearDown() { CurrentUserContext.resetForTesting(); super.tearDown() }

    func testServiceNamesLiveInTheAlfaNamespace() {
        let name = PerUserKeychainService.perUser("google", userID: "kennung")
        XCTAssertEqual(name, "com.johannesleoberger.alfaos.google.kennung")
        XCTAssertEqual(PerUserKeychainService.perUser("google", userID: nil), "com.johannesleoberger.alfaos.google.local")
    }

    func testAnEntryUnderTheAlphaNameIsNotRead() throws {
        let schrank = Attrappe()
        try schrank.store("alt", service: "de.mykilos.ALPHA.mac.google.kennung", account: "tokens")
        let neu = PerUserKeychainService.perUser("google", userID: "kennung")
        XCTAssertNil(try schrank.load(service: neu, account: "tokens"))
        XCTAssertEqual(schrank.content.count, 1, "nothing is copied over")
    }
}
