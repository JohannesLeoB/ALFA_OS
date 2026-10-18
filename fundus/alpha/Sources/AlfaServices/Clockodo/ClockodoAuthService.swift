import Foundation
import Observation
import AlfaKit

@MainActor
@Observable
public final class ClockodoAuthService {
    public private(set) var status: ClockodoConnectionStatus

    private let credentialsStore: ClockodoCredentialsStoring

    public init(credentialsStore: ClockodoCredentialsStoring = KeychainClockodoCredentialsStore()) {
        self.credentialsStore = credentialsStore
        self.status = (try? credentialsStore.load()) != nil ? .connected : .disconnected
    }

    public func storedCredentials() throws -> ClockodoCredentials? {
        try credentialsStore.load()
    }

    public func connect(email: String, apiKey: String) throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.isEmpty == false, trimmedApiKey.isEmpty == false else {
            status = .error("E-Mail oder API-Key fehlt")
            throw ClockodoError.notConnected
        }
        do {
            try credentialsStore.store(ClockodoCredentials(email: trimmedEmail, apiKey: trimmedApiKey))
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
