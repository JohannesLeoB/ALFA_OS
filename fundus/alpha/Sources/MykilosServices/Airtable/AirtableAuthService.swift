import Foundation
import Observation
import MykilosKit

public struct AirtableCredentials: Equatable, Sendable {
    public var pat: String
    public var baseID: String

    public init(pat: String, baseID: String) {
        self.pat = pat
        self.baseID = baseID
    }
}

public enum AirtableConnectionStatus: Equatable, Sendable {
    case disconnected
    case connected
    case syncing
    case error(String)
}

public protocol AirtableCredentialsStoring: Sendable {
    func store(_ credentials: AirtableCredentials) throws
    func load() throws -> AirtableCredentials?
    func clear() throws
}

public struct KeychainAirtableCredentialsStore: AirtableCredentialsStoring {
    private static let patAccount = "pat"
    private static let baseIDAccount = "baseID"
    private let vault: ServiceCredentialStore

    public init(keychain: KeychainStore = KeychainStore(), userID: String? = CurrentUserContext.current) {
        vault = ServiceCredentialStore(
            .airtable,
            fields: [CredentialField(Self.patAccount), CredentialField(Self.baseIDAccount)],
            keychain: keychain, userID: userID)
    }

    public func store(_ credentials: AirtableCredentials) throws {
        try vault.store([Self.patAccount: credentials.pat, Self.baseIDAccount: credentials.baseID])
    }

    public func load() throws -> AirtableCredentials? {
        guard let values = try vault.load(), let pat = values[Self.patAccount], let baseID = values[Self.baseIDAccount] else { return nil }
        return AirtableCredentials(pat: pat, baseID: baseID)
    }

    public func clear() throws {
        try vault.clear()
    }
}

extension AirtableConnectionStatus: AuthStatusValue {
    public var isConnected: Bool { self == .connected }
    public var isWorking: Bool { self == .syncing }
    public var failure: String? { if case .error(let message) = self { message } else { nil } }
}

@MainActor
@Observable
public final class AirtableAuthService {
    public private(set) var status: AirtableConnectionStatus

    private let credentialsStore: AirtableCredentialsStoring

    public init(credentialsStore: AirtableCredentialsStoring = KeychainAirtableCredentialsStore()) {
        self.credentialsStore = credentialsStore
        self.status = (try? credentialsStore.load()) != nil ? .connected : .disconnected
    }

    public func storedCredentials() throws -> AirtableCredentials? {
        guard let creds = try credentialsStore.load() else { return nil }

        if Self.looksLikeToken(creds.baseID), creds.pat.hasPrefix("app") {
            let healed = AirtableCredentials(pat: creds.baseID, baseID: creds.pat)
            try? credentialsStore.store(healed)
            return healed
        }
        return creds
    }

    static func looksLikeToken(_ s: String) -> Bool {
        s.hasPrefix("pat") || s.hasPrefix("key")
    }

    public func connect(pat: String, baseID: String) throws {
        let trimmedPAT = pat.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBase = baseID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPAT.isEmpty, !trimmedBase.isEmpty else {
            status = .error("PAT oder Base-ID fehlt")
            throw AirtableError.notConnected
        }
        guard trimmedBase.hasPrefix("app"), (15...22).contains(trimmedBase.count) else {
            let msg = "Base-ID muss mit \u{201E}app\u{201C} beginnen (z.\u{202F}B. \(try CompanySetup.value("airtable.base.writable_test"))) \u{2013} vermutlich wurde der PAT ins Base-ID-Feld eingef\u{FC}gt."
            status = .error(msg)
            throw AirtableError.invalidBaseID(trimmedBase)
        }
        do {
            try credentialsStore.store(AirtableCredentials(pat: trimmedPAT, baseID: trimmedBase))
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

    public func setSyncing() { status = .syncing }
    public func setSynced() { status = .connected }
    public func setError(_ message: String) { status = .error(message) }
}
