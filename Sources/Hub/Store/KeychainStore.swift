import Core
import Foundation
import LocalAuthentication
import Security

public struct KeychainStore: KeychainPort {
    static let encodingStatus: Int32 = -1

    private let prefix: String

    public init(prefix: String = AppIdentity.keychainPrefix) {
        self.prefix = prefix
    }

    static func service(for slot: KeySlot, prefix: String = AppIdentity.keychainPrefix) -> String {
        prefix + "hub." + slot.inlet
    }

    static func account(for slot: KeySlot) -> String {
        slot.name
    }

    private func identity(_ slot: KeySlot) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service(for: slot, prefix: prefix),
            kSecAttrAccount: Self.account(for: slot),
        ]
    }

    public func put(_ value: String, at slot: KeySlot) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainFailure.status(Self.encodingStatus) }
        let query = identity(slot)
        let added = SecItemAdd(query.merging([kSecValueData: data]) { _, new in new } as CFDictionary, nil)
        if added == errSecSuccess { return }
        guard added == errSecDuplicateItem else { throw KeychainFailure.status(added) }
        let updated = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        guard updated == errSecSuccess else { throw KeychainFailure.status(updated) }
    }

    public func get(_ slot: KeySlot) throws -> String? {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query = identity(slot).merging([
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context,
        ]) { _, new in new }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainFailure.status(status) }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainFailure.status(Self.encodingStatus)
        }
        return value
    }

    public func delete(_ slot: KeySlot) throws {
        let status = SecItemDelete(identity(slot) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainFailure.status(status) }
    }
}
