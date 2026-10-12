import Foundation
import MykilosKit

public enum CurrentUserContext {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _userID: String?

    nonisolated(unsafe) private static var _vorherige: String?

    public static func set(_ userID: String?) {
        lock.lock(); defer { lock.unlock() }
        if let alt = _userID, alt != userID { _vorherige = alt }
        _userID = userID
    }

    public static var vorherige: String? {
        lock.lock(); defer { lock.unlock() }
        return _vorherige
    }

    public static var current: String? {
        lock.lock(); defer { lock.unlock() }
        return _userID
    }

    public static func resetForTesting() {
        lock.lock(); defer { lock.unlock() }
        _userID = nil
        _vorherige = nil
    }

    public static let timerFallbackID = "local"
    public static let chatMemoryFallbackScope = "shared"
}

public enum PerUserKeychainService {
    public static func legacy(_ base: String) -> String {
        "\(AppKennung.schluesselbundPraefix)\(base)"
    }

    public static func candidates(_ base: String, userID: String?) -> [String] {
        var namen = [perUser(base, userID: userID)]
        if let vorherige = CurrentUserContext.vorherige {
            let alt = perUser(base, userID: vorherige)
            if namen.contains(alt) == false { namen.append(alt) }
        }
        namen.append(legacy(base))
        return namen
    }

    public static func perUser(_ base: String, userID: String?) -> String {
        let trimmed = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let safeUserID = trimmed.isEmpty ? "local" : trimmed
        return "\(AppKennung.schluesselbundPraefix)\(base).\(safeUserID)"
    }
}

public protocol KeychainAccessing: Sendable {
    func load(service: String, account: String) throws -> String?
    @discardableResult
    func store(_ value: String, service: String, account: String) throws -> Bool
}

extension KeychainStore: KeychainAccessing {}

public enum PerUserKeychainMigrator {
    static let personalBases: Set<String> = Set(KeyIntegration.allCases.filter { $0.scope == .persoenlich }.map(\.keychainBase))

    public static func loadWithMigration(
        keychain: some KeychainAccessing,
        base: String,
        userID: String?,
        account: String
    ) throws -> String? {
        let newService = PerUserKeychainService.perUser(base, userID: userID)
        if let value = try keychain.load(service: newService, account: account) {
            return value
        }

        if Self.personalBases.contains(base),
           let primary = try? keychain.load(
                service: KeychainIdentityAnchorStore.service,
                account: KeychainIdentityAnchorStore.devicePrimaryAccount),
           case let trimmedPrimary = primary.trimmingCharacters(in: .whitespacesAndNewlines),
           trimmedPrimary.isEmpty == false {
            let currentTrimmed = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let effectiveUserID = currentTrimmed.isEmpty ? "local" : currentTrimmed
            if effectiveUserID != trimmedPrimary {
                return nil
            }
        }

        let oldService = PerUserKeychainService.legacy(base)
        if let legacyValue = try keychain.load(service: oldService, account: account) {
            try keychain.store(legacyValue, service: newService, account: account)
            return legacyValue
        }

        let localService = PerUserKeychainService.perUser(base, userID: nil)
        if localService != newService,
           let localValue = try keychain.load(service: localService, account: account) {
            try keychain.store(localValue, service: newService, account: account)
            return localValue
        }

        if let vorherige = CurrentUserContext.vorherige {
            let altService = PerUserKeychainService.perUser(base, userID: vorherige)
            if altService != newService, altService != localService,
               let alterWert = try keychain.load(service: altService, account: account) {
                try keychain.store(alterWert, service: newService, account: account)
                return alterWert
            }
        }
        return nil
    }
}
