import Foundation

public struct KeychainNamespace: Equatable, Sendable {
    public let servicePrefix: String
    public let accessLabel: String

    public init(bundleIdentifier: String, appName: String) {
        self.servicePrefix = "\(bundleIdentifier)."
        self.accessLabel = "\(appName) credentials"
    }

    public var identityService: String { "\(servicePrefix)identity" }
}

public enum CurrentUserContext {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _userID: String?

    nonisolated(unsafe) private static var _previous: String?

    public static func set(_ userID: String?) {
        lock.lock(); defer { lock.unlock() }
        if let old = _userID, old != userID { _previous = old }
        _userID = userID
    }

    public static var previous: String? {
        lock.lock(); defer { lock.unlock() }
        return _previous
    }

    public static var current: String? {
        lock.lock(); defer { lock.unlock() }
        return _userID
    }

    public static func resetForTesting() {
        lock.lock(); defer { lock.unlock() }
        _userID = nil
        _previous = nil
    }
}

public enum PerUserKeychainService {
    public static func legacy(_ base: String, namespace: KeychainNamespace) -> String {
        "\(namespace.servicePrefix)\(base)"
    }

    public static func candidates(_ base: String, userID: String?, namespace: KeychainNamespace) -> [String] {
        var names = [perUser(base, userID: userID, namespace: namespace)]
        if let previous = CurrentUserContext.previous {
            let old = perUser(base, userID: previous, namespace: namespace)
            if names.contains(old) == false { names.append(old) }
        }
        names.append(legacy(base, namespace: namespace))
        return names
    }

    public static func perUser(_ base: String, userID: String?, namespace: KeychainNamespace) -> String {
        let trimmed = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let safeUserID = trimmed.isEmpty ? "local" : trimmed
        return "\(namespace.servicePrefix)\(base).\(safeUserID)"
    }
}

public protocol KeychainAccessing: Sendable {
    var namespace: KeychainNamespace { get }
    func load(service: String, account: String) throws -> String?
    @discardableResult
    func store(_ value: String, service: String, account: String) throws -> Bool
}

extension KeychainStore: KeychainAccessing {}

public enum PerUserKeychainMigrator {
    static let personalBases: Set<String> = Set(KeyIntegration.allCases.filter { $0.scope == .personal }.map(\.keychainBase))

    public static func loadWithMigration(
        keychain: some KeychainAccessing,
        base: String,
        userID: String?,
        account: String
    ) throws -> String? {
        let namespace = keychain.namespace
        let newService = PerUserKeychainService.perUser(base, userID: userID, namespace: namespace)
        if let value = try keychain.load(service: newService, account: account) {
            return value
        }

        if Self.personalBases.contains(base),
           let primary = try? keychain.load(
                service: namespace.identityService,
                account: KeychainIdentityAnchorStore.devicePrimaryAccount),
           case let trimmedPrimary = primary.trimmingCharacters(in: .whitespacesAndNewlines),
           trimmedPrimary.isEmpty == false {
            let currentTrimmed = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let effectiveUserID = currentTrimmed.isEmpty ? "local" : currentTrimmed
            if effectiveUserID != trimmedPrimary {
                return nil
            }
        }

        let oldService = PerUserKeychainService.legacy(base, namespace: namespace)
        if let legacyValue = try keychain.load(service: oldService, account: account) {
            try keychain.store(legacyValue, service: newService, account: account)
            return legacyValue
        }

        let localService = PerUserKeychainService.perUser(base, userID: nil, namespace: namespace)
        if localService != newService,
           let localValue = try keychain.load(service: localService, account: account) {
            try keychain.store(localValue, service: newService, account: account)
            return localValue
        }

        if let previous = CurrentUserContext.previous {
            let previousService = PerUserKeychainService.perUser(base, userID: previous, namespace: namespace)
            if previousService != newService, previousService != localService,
               let previousValue = try keychain.load(service: previousService, account: account) {
                try keychain.store(previousValue, service: newService, account: account)
                return previousValue
            }
        }
        return nil
    }
}
