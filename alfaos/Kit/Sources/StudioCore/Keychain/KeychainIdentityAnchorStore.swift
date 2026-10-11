import Foundation

public protocol IdentityAnchorStoring: Sendable {
    func save(userID: String, forEmail email: String) throws

    func userID(forEmail email: String) throws -> String?
}

public struct KeychainIdentityAnchorStore: IdentityAnchorStoring {
    private let keychain: any KeychainAccessing

    public init(keychain: any KeychainAccessing) {
        self.keychain = keychain
    }

    public var service: String { keychain.namespace.identityService }

    private static func normalizedEmail(_ email: String) -> String? {
        let key = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return key.isEmpty ? nil : key
    }

    public func save(userID: String, forEmail email: String) throws {
        guard let account = Self.normalizedEmail(email) else { return }
        let value = userID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard value.isEmpty == false else { return }
        try keychain.store(value, service: service, account: account)
    }

    public func userID(forEmail email: String) throws -> String? {
        guard let account = Self.normalizedEmail(email) else { return nil }
        guard let value = try keychain.load(service: service, account: account) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let lastEmailAccount = "__last_email__"

    public func saveLastEmail(_ email: String) throws {
        guard let normalized = Self.normalizedEmail(email) else { return }
        try keychain.store(normalized, service: service, account: Self.lastEmailAccount)
    }

    public func loadLastEmail() throws -> String? {
        guard let value = try keychain.load(service: service, account: Self.lastEmailAccount) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static let devicePrimaryAccount = "__device_primary_userID__"

    public func ensureDevicePrimary(_ userID: String) throws {
        let value = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { return }
        if let existing = try keychain.load(service: service, account: Self.devicePrimaryAccount),
           existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return
        }
        try keychain.store(value, service: service, account: Self.devicePrimaryAccount)
    }

    public func loadDevicePrimary() throws -> String? {
        guard let value = try keychain.load(service: service, account: Self.devicePrimaryAccount) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static let signedOutAccount = "__signed_out__"

    public func markSignedOut() throws {
        try keychain.store("1", service: service, account: Self.signedOutAccount)
    }

    public func clearSignedOut() throws {
        try keychain.store("", service: service, account: Self.signedOutAccount)
    }

    public func isSignedOut() throws -> Bool {
        guard let value = try keychain.load(service: service, account: Self.signedOutAccount) else { return false }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    public static let backfillDoneAccount = "__backfill_done__"

    public func markBackfillDone() throws {
        try keychain.store("1", service: service, account: Self.backfillDoneAccount)
    }

    public func isBackfillDone() throws -> Bool {
        guard let value = try keychain.load(service: service, account: Self.backfillDoneAccount) else { return false }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
