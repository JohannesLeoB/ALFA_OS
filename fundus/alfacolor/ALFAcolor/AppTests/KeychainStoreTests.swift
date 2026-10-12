import Foundation
import Security
import Testing

/// Each test uses its own service name and removes what it wrote, so the keychain of the app stays untouched.
struct KeychainStoreTests {
    private static func store() -> KeychainStore {
        KeychainStore(service: "com.johannesleoberger.alfacolor.tests.\(UUID().uuidString)")
    }

    private static func attributes(service: String, account: String) -> [String: Any]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? [String: Any]
    }

    private static func setComment(_ comment: String, service: String, account: String) -> OSStatus {
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemUpdate(match as CFDictionary, [kSecAttrComment as String: comment] as CFDictionary)
    }

    @Test("a secret is written, read back, replaced and removed")
    func roundTrip() throws {
        let store = Self.store()
        defer { try? store.delete(account: "key") }
        #expect(try store.read(account: "key") == nil)
        try store.write("first", account: "key")
        #expect(try store.read(account: "key") == "first")
        try store.write("second", account: "key")
        #expect(try store.read(account: "key") == "second")
        try store.delete(account: "key")
        #expect(try store.read(account: "key") == nil)
        try store.delete(account: "key")
    }

    @Test("replacing a secret updates the item in place instead of deleting it first")
    func overwriteKeepsTheItem() throws {
        let store = Self.store()
        defer { try? store.delete(account: "key") }
        try store.write("first", account: "key")
        #expect(Self.setComment("marker", service: store.service, account: "key") == errSecSuccess)
        try store.write("second", account: "key")
        #expect(try store.read(account: "key") == "second")
        #expect(Self.attributes(service: store.service, account: "key")?[kSecAttrComment as String] as? String == "marker")
    }

    @Test("reading asks for exactly one match")
    func readAsksForOneMatch() {
        let query = Self.store().readQuery(account: "key")
        #expect(query[kSecMatchLimit as String] as? String == kSecMatchLimitOne as String)
        #expect(query[kSecReturnData as String] as? Bool == true)
    }
}
