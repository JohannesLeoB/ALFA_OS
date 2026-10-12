import Foundation

public struct ClockodoCredentials: Equatable, Sendable {
    public var email: String
    public var apiKey: String

    public init(email: String, apiKey: String) {
        self.email = email
        self.apiKey = apiKey
    }
}

public protocol ClockodoCredentialsStoring: Sendable {
    func store(_ credentials: ClockodoCredentials) throws
    func load() throws -> ClockodoCredentials?
    func clear() throws
}

public struct KeychainClockodoCredentialsStore: ClockodoCredentialsStoring {
    private static let emailAccount = "email"
    private static let apiKeyAccount = "apiKey"
    private let vault: ServiceCredentialStore

    public init(keychain: KeychainStore = KeychainStore(), userID: String? = CurrentUserContext.current) {
        vault = ServiceCredentialStore(
            .clockodo,
            fields: [CredentialField(Self.emailAccount), CredentialField(Self.apiKeyAccount)],
            keychain: keychain, userID: userID)
    }

    public func store(_ credentials: ClockodoCredentials) throws {
        try vault.store([Self.emailAccount: credentials.email, Self.apiKeyAccount: credentials.apiKey])
    }

    public func load() throws -> ClockodoCredentials? {
        guard let values = try vault.load(), let email = values[Self.emailAccount], let apiKey = values[Self.apiKeyAccount] else { return nil }
        return ClockodoCredentials(email: email, apiKey: apiKey)
    }

    public func clear() throws {
        try vault.clear()
    }
}
