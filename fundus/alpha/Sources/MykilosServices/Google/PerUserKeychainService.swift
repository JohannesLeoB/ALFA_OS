import Foundation
import MykilosKit

public enum CurrentUserContext {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _userID: String?

    public static func set(_ userID: String?) {
        lock.lock(); defer { lock.unlock() }
        _userID = userID
    }

    public static var current: String? {
        lock.lock(); defer { lock.unlock() }
        return _userID
    }

    public static func resetForTesting() {
        lock.lock(); defer { lock.unlock() }
        _userID = nil
    }

    public static let timerFallbackID = "local"
    public static let chatMemoryFallbackScope = "shared"
}

public enum PerUserKeychainService {
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
