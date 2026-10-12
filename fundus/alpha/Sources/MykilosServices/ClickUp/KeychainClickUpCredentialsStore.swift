import Foundation

public struct ClickUpCredentials: Equatable, Sendable {
    public var apiToken: String

    public init(apiToken: String) {
        self.apiToken = apiToken
    }
}

public protocol ClickUpCredentialsStoring: Sendable {
    func store(_ credentials: ClickUpCredentials) throws
    func load() throws -> ClickUpCredentials?
    func clear() throws
}

public struct KeychainClickUpCredentialsStore: ClickUpCredentialsStoring {
    private static let tokenAccount = "apiToken"
    private let vault: ServiceCredentialStore

    public init(keychain: KeychainStore = KeychainStore(), userID: String? = CurrentUserContext.current) {
        vault = ServiceCredentialStore(.clickup, fields: [CredentialField(Self.tokenAccount)], keychain: keychain, userID: userID)
    }

    public func store(_ credentials: ClickUpCredentials) throws {
        try vault.store([Self.tokenAccount: credentials.apiToken])
    }

    public func load() throws -> ClickUpCredentials? {
        guard let values = try vault.load(), let value = values[Self.tokenAccount] else { return nil }
        return ClickUpCredentials(apiToken: value)
    }

    public func clear() throws {
        try vault.clear()
    }
}
