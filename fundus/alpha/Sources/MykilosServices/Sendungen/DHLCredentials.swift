import Foundation

public struct DHLCredentials: Equatable, Sendable {
    public var apiKey: String
    public init(apiKey: String) { self.apiKey = apiKey }
}

public protocol DHLCredentialsStoring: Sendable {
    func store(_ credentials: DHLCredentials) throws
    func load() throws -> DHLCredentials?
    func clear() throws
}

public struct KeychainDHLCredentialsStore: DHLCredentialsStoring {
    private static let account = "apiKey"
    private let vault: ServiceCredentialStore

    public init(keychain: KeychainStore = KeychainStore(), userID: String? = CurrentUserContext.current) {
        vault = ServiceCredentialStore(.dhlTracking, fields: [CredentialField(Self.account)], keychain: keychain, userID: userID)
    }

    public func store(_ credentials: DHLCredentials) throws {
        try vault.store([Self.account: credentials.apiKey])
    }

    public func load() throws -> DHLCredentials? {
        guard let values = try vault.load(), let value = values[Self.account] else { return nil }
        return DHLCredentials(apiKey: value)
    }

    public func clear() throws {
        try vault.clear()
    }
}
