import Foundation

public enum CompanySetupError: Error, Sendable {
    case missing(String)
}

public enum CompanySetup {
    private static let values: [String: String] = load()
    private static let missing = MissingKeys()

    public static var missingKeys: Set<String> { missing.snapshot() }

    public static func value(_ key: String) throws -> String {
        guard let text = values[key], text.isEmpty == false else { throw CompanySetupError.missing(key) }
        return text
    }

    public static func valueOrEmpty(_ key: String) -> String {
        guard let text = values[key], text.isEmpty == false else {
            missing.insert(key)
            return ""
        }
        return text
    }

    private static func load() -> [String: String] {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return [:] }
        let url = base.appendingPathComponent("ALFA_OS", isDirectory: true).appendingPathComponent("company.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object.compactMapValues { $0 as? String }
    }

    private final class MissingKeys: @unchecked Sendable {
        private let lock = NSLock()
        private var keys: Set<String> = []

        func insert(_ key: String) {
            lock.lock()
            keys.insert(key)
            lock.unlock()
        }

        func snapshot() -> Set<String> {
            lock.lock()
            defer { lock.unlock() }
            return keys
        }
    }
}
