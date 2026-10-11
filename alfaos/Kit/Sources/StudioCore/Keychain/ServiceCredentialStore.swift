import Foundation

public struct CredentialField: Sendable {
    public let account: String
    public let isRequired: Bool

    public init(_ account: String, isRequired: Bool = true) {
        self.account = account
        self.isRequired = isRequired
    }
}

public struct ServiceCredentialStore: Sendable {
    private let keychain: KeychainStore
    private let base: String
    private let fields: [CredentialField]
    private let userID: String?

    public init(
        _ integration: KeyIntegration,
        fields: [CredentialField],
        keychain: KeychainStore,
        userID: String? = CurrentUserContext.current
    ) {
        self.keychain = keychain
        self.base = integration.keychainBase
        self.fields = fields
        self.userID = userID
    }

    private var service: String {
        PerUserKeychainService.perUser(base, userID: userID, namespace: keychain.namespace)
    }

    public func store(_ values: [String: String], remove: Set<String> = []) throws {
        for field in fields {
            if let value = values[field.account] {
                try keychain.store(value, service: service, account: field.account)
            } else if remove.contains(field.account) {
                try keychain.delete(service: service, account: field.account)
            }
        }
    }

    public func load() throws -> [String: String]? {
        var found: [String: String] = [:]
        for field in fields {
            let value: String?
            if field.isRequired {
                value = try PerUserKeychainMigrator.loadWithMigration(
                    keychain: keychain, base: base, userID: userID, account: field.account)
            } else {
                value = try? PerUserKeychainMigrator.loadWithMigration(
                    keychain: keychain, base: base, userID: userID, account: field.account)
            }
            if let value, value.isEmpty == false {
                found[field.account] = value
            } else if field.isRequired {
                return nil
            }
        }
        return found
    }

    public func clear() throws {
        for field in fields {
            try keychain.delete(service: service, account: field.account)
        }
    }
}
