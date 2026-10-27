public enum AppearanceChoice: String, CaseIterable, Sendable {
    case light
    case dark
    case system

    public var key: String { "settings.appearance." + rawValue }
}
