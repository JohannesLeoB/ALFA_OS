import Foundation

public enum ChannelInitials {
    public static let storageKey = "followUp.channelInitials"

    public static var current: [String] {
        UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    }

    public static var isConfigured: Bool {
        UserDefaults.standard.object(forKey: storageKey) != nil
    }

    public static func save(_ initials: [String]) {
        UserDefaults.standard.set(initials, forKey: storageKey)
    }
}
