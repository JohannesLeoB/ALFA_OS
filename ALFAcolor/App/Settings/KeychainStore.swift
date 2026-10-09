import Foundation
import Security

/// Keeps secrets in the keychain, one generic password per account. The service is the bundle ID of the app,
/// unless a test gives another one.
/// No caller yet: the account connection will be the first one to read and write secrets here.
struct KeychainStore {
    /// The service of the app. Only the app itself writes to it.
    static let appService = Bundle.main.bundleIdentifier ?? "com.johannesleoberger.alfacolor"

    let service: String

    init(service: String = KeychainStore.appService) {
        self.service = service
    }

    enum Failure: Error, Equatable {
        case status(OSStatus)
        case encoding
    }

    /// Writes a secret, replacing the one that is there.
    func write(_ secret: String, account: String) throws {
        guard let data = secret.data(using: .utf8) else { throw Failure.encoding }
        try delete(account: account)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.status(status) }
    }

    /// Reads a secret. nil when there is none.
    func read(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimitOne as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let secret = String(data: data, encoding: .utf8) else { throw Failure.status(status) }
        return secret
    }

    /// Removes a secret. Nothing to remove is not an error.
    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.status(status) }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
