import Hub
import XCTest

final class AdapterKeychainTests: XCTestCase {
    func testServiceNameFollowsPrefixAndInlet() {
        let slot = KeySlot(inlet: "imap-123", name: "password")
        XCTAssertEqual(KeychainAdapter.service(for: slot, prefix: "p."), "p.hub.imap-123")
        XCTAssertEqual(KeychainAdapter.account(for: slot), "password")
    }

    func testDefaultPrefixIsTheAppNamespace() {
        let slot = KeySlot(inlet: "google-1", name: "refresh")
        XCTAssertEqual(KeychainAdapter.service(for: slot), "com.johannesleoberger.alfaos.hub.google-1")
    }

    func testSlotsOfOneInletShareTheServiceAndDifferInAccount() {
        let a = KeySlot(inlet: "x", name: "a"), b = KeySlot(inlet: "x", name: "b")
        XCTAssertEqual(KeychainAdapter.service(for: a), KeychainAdapter.service(for: b))
        XCTAssertNotEqual(KeychainAdapter.account(for: a), KeychainAdapter.account(for: b))
        XCTAssertNotEqual(KeychainAdapter.service(for: a), KeychainAdapter.service(for: KeySlot(inlet: "y", name: "a")))
    }
}
