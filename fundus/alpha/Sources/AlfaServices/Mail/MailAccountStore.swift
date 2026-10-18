import Foundation
import AlfaKit

public enum MailAccountStoreError: Error, Equatable, Sendable {
    case invalidAddress
    case missingPassword
    case duplicateAddress
    case primaryAccount
    case unknownAccount
}

@MainActor
public struct MailAccountStore {
    public static let primaryID = "google.primary"
    public static let storageKey = "mail.accounts"

    private let defaults: UserDefaults
    private let primaryUser: @MainActor () -> GoogleUserInfo?
    private let keychain: KeychainStore

    public init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore(),
                primaryUser: @escaping @MainActor () -> GoogleUserInfo?) {
        self.defaults = defaults
        self.keychain = keychain
        self.primaryUser = primaryUser
    }

    public var primaryAccount: MailAccount? {
        guard let user = primaryUser(), user.email.isEmpty == false else { return nil }
        return MailProviderPresets.preset(for: .gmail).account(
            id: Self.primaryID, displayName: user.displayName, address: user.email)
    }

    public var storedAccounts: [MailAccount] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let accounts = try? JSONDecoder().decode([MailAccount].self, from: data) else { return [] }
        return accounts.filter { $0.id != Self.primaryID }
    }

    public var accounts: [MailAccount] {
        (primaryAccount.map { [$0] } ?? []) + storedAccounts
    }

    public func account(id: String) -> MailAccount? {
        accounts.first { $0.id == id }
    }

    public func add(_ account: MailAccount, password: String?) throws {
        let address = account.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.contains("@"), address.hasPrefix("@") == false, address.hasSuffix("@") == false else {
            throw MailAccountStoreError.invalidAddress
        }
        guard accounts.contains(where: { $0.address.caseInsensitiveCompare(address) == .orderedSame }) == false else {
            throw MailAccountStoreError.duplicateAddress
        }
        if account.authentication == .password {
            guard let password, password.isEmpty == false else { throw MailAccountStoreError.missingPassword }
            try secrets(for: account.id).store([account.id: password])
        }
        var next = storedAccounts
        var stored = account
        stored.address = address
        next.append(stored)
        try save(next)
    }

    public func remove(id: String) throws {
        guard id != Self.primaryID else { throw MailAccountStoreError.primaryAccount }
        let current = storedAccounts
        guard current.contains(where: { $0.id == id }) else { throw MailAccountStoreError.unknownAccount }
        try secrets(for: id).clear()
        try save(current.filter { $0.id != id })
    }

    public func removeAllStored() throws {
        for account in storedAccounts { try remove(id: account.id) }
    }

    public func password(for id: String) throws -> String? {
        try secrets(for: id).load()?[id]
    }

    private func secrets(for id: String) -> ServiceCredentialStore {
        ServiceCredentialStore(.mail, fields: [CredentialField(id)], keychain: keychain)
    }

    private func save(_ accounts: [MailAccount]) throws {
        defaults.set(try JSONEncoder().encode(accounts), forKey: Self.storageKey)
    }
}
