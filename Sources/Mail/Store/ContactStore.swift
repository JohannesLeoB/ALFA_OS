import Foundation

public struct ContactStore: ContactBookPort {
    static let storageKey = "mail.contacts"

    let defaults: UserDefaults?

    public init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    public func load() -> [Contact] {
        guard let data = defaults?.data(forKey: Self.storageKey) else { return [] }
        return (try? JSONDecoder().decode([Contact].self, from: data)) ?? []
    }

    public func save(_ contacts: [Contact]) throws {
        guard let defaults else { return }
        defaults.set(try JSONEncoder().encode(contacts), forKey: Self.storageKey)
    }
}
