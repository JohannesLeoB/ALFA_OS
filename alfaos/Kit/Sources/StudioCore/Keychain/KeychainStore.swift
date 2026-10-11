import Foundation
import Security

public enum KeychainStoreError: Error, Sendable {
    case encodingFailed
    case writeFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
}

public struct KeychainStore: Sendable {
    public let namespace: KeychainNamespace

    public init(namespace: KeychainNamespace) {
        self.namespace = namespace
    }

    @discardableResult
    public func store(_ value: String, service: String, account: String) throws -> Bool {
        guard let data = value.data(using: .utf8) else { throw KeychainStoreError.encodingFailed }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        var addAttributes: [CFString: Any] = [kSecValueData: data]
        #if os(macOS)
        let allowAllAccess = Self.makeAllowAllApplicationsAccess(label: namespace.accessLabel)
        if let allowAllAccess {
            addAttributes[kSecAttrAccess] = allowAllAccess
        } else {
            addAttributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        #else
        addAttributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        #endif
        let addQuery = query.merging(addAttributes) { _, new in new }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess { return true }

        guard addStatus == errSecDuplicateItem else {
            throw KeychainStoreError.writeFailed(addStatus)
        }

        let updateAttributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw KeychainStoreError.writeFailed(updateStatus)
        }
        return false
    }

    public func load(service: String, account: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationUI: kSecUseAuthenticationUISkip
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.readFailed(status) }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainStoreError.encodingFailed
        }
        return value
    }

    public func delete(service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.deleteFailed(status)
        }
    }

    #if os(macOS)
    private static func makeAllowAllApplicationsAccess(label: String) -> SecAccess? {
        var access: SecAccess?
        let status = SecAccessCreate(label as CFString, nil, &access)
        guard status == errSecSuccess, let access else { return nil }
        if let aclList = SecAccessCopyMatchingACLList(access, kSecACLAuthorizationDecrypt) as? [SecACL] {
            for acl in aclList {
                SecACLSetContents(acl, nil, "" as CFString, SecKeychainPromptSelector())
            }
        }
        return access
    }
    #endif
}
