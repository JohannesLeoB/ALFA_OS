import Foundation
import Observation
import AlfaKit

public struct ClaudeCredentials: Equatable, Sendable {
    public var apiKey: String
    public var model: String

    public init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }
}

public enum ClaudeConnectionStatus: Equatable, Sendable {
    case disconnected
    case connected
    case error(String)
}

public protocol ClaudeCredentialsStoring: Sendable {
    func store(_ credentials: ClaudeCredentials) throws
    func load() throws -> ClaudeCredentials?
    func clear() throws
}

public struct KeychainClaudeCredentialsStore: ClaudeCredentialsStoring {
    private static let apiKeyAccount = "apiKey"
    private static let modelAccount = "model"
    private let vault: ServiceCredentialStore

    public init(keychain: KeychainStore = KeychainStore(), userID: String? = CurrentUserContext.current) {
        vault = ServiceCredentialStore(
            .claude,
            fields: [CredentialField(Self.apiKeyAccount), CredentialField(Self.modelAccount)],
            keychain: keychain, userID: userID)
    }

    public func store(_ credentials: ClaudeCredentials) throws {
        try vault.store([Self.apiKeyAccount: credentials.apiKey, Self.modelAccount: credentials.model])
    }

    public func load() throws -> ClaudeCredentials? {
        guard let values = try vault.load(), let apiKey = values[Self.apiKeyAccount], let model = values[Self.modelAccount] else { return nil }
        return ClaudeCredentials(apiKey: apiKey, model: model)
    }

    public func clear() throws {
        try vault.clear()
    }
}

extension ClaudeConnectionStatus: AuthStatusValue {
    public var isConnected: Bool { self == .connected }
    public var failure: String? { if case .error(let message) = self { message } else { nil } }
}

@MainActor
@Observable
public final class ClaudeAuthService {
    public static let defaultModel = "claude-sonnet-4-6"

    public private(set) var status: ClaudeConnectionStatus

    private let credentialsStore: ClaudeCredentialsStoring

    public init(credentialsStore: ClaudeCredentialsStoring = KeychainClaudeCredentialsStore()) {
        self.credentialsStore = credentialsStore
        self.status = (try? credentialsStore.load()) != nil ? .connected : .disconnected
    }

    public func storedCredentials() throws -> ClaudeCredentials? {
        try credentialsStore.load()
    }

    public func connect(apiKey: String, model: String) throws {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedKey.isEmpty == false else {
            status = .error("API-Key fehlt")
            throw ClaudeClientError.notConnected
        }
        let modelValue = trimmedModel.isEmpty ? Self.defaultModel : trimmedModel
        do {
            try credentialsStore.store(ClaudeCredentials(apiKey: trimmedKey, model: modelValue))
            status = .connected
        } catch {
            status = .error(String(describing: error))
            throw error
        }
    }

    public func disconnect() throws {
        try credentialsStore.clear()
        status = .disconnected
    }
}
