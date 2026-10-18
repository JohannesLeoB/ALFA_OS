import Foundation

public struct SevdeskCredentials: Equatable, Sendable {
    public var apiToken: String

    public init(apiToken: String) {
        self.apiToken = apiToken
    }
}

public protocol SevdeskCredentialsStoring: Sendable {
    func store(_ credentials: SevdeskCredentials) throws
    func load() throws -> SevdeskCredentials?
    func clear() throws
}

public struct KeychainSevdeskCredentialsStore: SevdeskCredentialsStoring {
    private static let tokenAccount = "apiToken"
    private let vault: ServiceCredentialStore

    public init(keychain: KeychainStore = KeychainStore(), userID: String? = CurrentUserContext.current) {
        vault = ServiceCredentialStore(.sevdesk, fields: [CredentialField(Self.tokenAccount)], keychain: keychain, userID: userID)
    }

    public func store(_ credentials: SevdeskCredentials) throws {
        try vault.store([Self.tokenAccount: credentials.apiToken])
    }

    public func load() throws -> SevdeskCredentials? {
        guard let values = try vault.load(), let value = values[Self.tokenAccount] else { return nil }
        return SevdeskCredentials(apiToken: value)
    }

    public func clear() throws {
        try vault.clear()
    }
}
