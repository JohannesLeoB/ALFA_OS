import Foundation

public struct ShellStore {
    private static let key = "shell.snapshot"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Snapshot? {
        defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
    }

    public func save(_ snapshot: Snapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
