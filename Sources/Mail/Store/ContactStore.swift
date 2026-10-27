import Foundation

struct ContactStore {
    static let storageKey = "mail.contacts"

    let defaults: UserDefaults?

    func load() -> [Contact] {
        guard let data = defaults?.data(forKey: Self.storageKey) else { return [] }
        return (try? JSONDecoder().decode([Contact].self, from: data)) ?? []
    }

    func save(_ contacts: [Contact]) {
        guard let defaults else { return }
        defaults.set(try? JSONEncoder().encode(contacts), forKey: Self.storageKey)
    }
}
