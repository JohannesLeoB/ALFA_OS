import Foundation

public struct TeamMember: Identifiable, Equatable, Sendable, Codable {
    public var kuerzel: String
    public var clickUpMemberID: String
    public var colorID: String?
    public var id: String { kuerzel }

    public init(kuerzel: String, clickUpMemberID: String, colorID: String? = nil) {
        self.kuerzel = kuerzel
        self.clickUpMemberID = clickUpMemberID
        self.colorID = colorID
    }
}

public enum TeamRoster {
    public static let storageKey = "clickup.teamRoster"

    private final class Cache: @unchecked Sendable {
        let lock = NSLock()
        var data: Data?
        var members: [TeamMember] = []
    }

    private static let cache = Cache()

    public static var alle: [TeamMember] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        cache.lock.lock()
        defer { cache.lock.unlock() }
        if data != cache.data {
            cache.members = (try? JSONDecoder().decode([TeamMember].self, from: data)) ?? []
            cache.data = data
        }
        return cache.members
    }

    public static var isConfigured: Bool {
        UserDefaults.standard.object(forKey: storageKey) != nil
    }

    public static func save(_ members: [TeamMember]) {
        guard let data = try? JSONEncoder().encode(members) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    public static func kuerzel(fuerClickUpMemberID memberID: String?) -> String? {
        guard let memberID else { return nil }
        return alle.first { $0.clickUpMemberID == memberID }?.kuerzel
    }
}
