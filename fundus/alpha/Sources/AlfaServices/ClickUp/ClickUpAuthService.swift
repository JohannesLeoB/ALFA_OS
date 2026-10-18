import Foundation
import Observation
import AlfaKit

@MainActor
@Observable
public final class ClickUpAuthService {
    public private(set) var status: ClickUpConnectionStatus

    private let credentialsStore: ClickUpCredentialsStoring

    public init(credentialsStore: ClickUpCredentialsStoring = KeychainClickUpCredentialsStore()) {
        self.credentialsStore = credentialsStore
        self.status = (try? credentialsStore.load()) != nil ? .connected : .disconnected
    }

    public func storedCredentials() throws -> ClickUpCredentials? {
        try credentialsStore.load()
    }

    public func connect(apiToken: String) throws {
        let trimmed = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            status = .error("API-Token fehlt")
            throw ClickUpError.notConnected
        }
        do {
            try credentialsStore.store(ClickUpCredentials(apiToken: trimmed))
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
