public enum SettingsGroup: String, CaseIterable, Sendable {
    case me
    case connections
    case system

    public var key: String { "settings.group." + rawValue }
}

public enum SettingsSection: String, CaseIterable, Sendable, Identifiable {
    case appearance
    case integrations
    case system

    public var id: String { rawValue }

    public var group: SettingsGroup {
        switch self {
        case .appearance: .me
        case .integrations: .connections
        case .system: .system
        }
    }

    public var key: String { "settings.section." + rawValue }
}

public enum AppearanceChoice: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    public var key: String { "settings.appearance." + rawValue }
}

public enum SettingsLabel: String, CaseIterable, Sendable {
    case version
    case tokenDelivery
    case tokenDeliveredAt
    case tokenAdoptedAt
    case tokenState

    public var key: String { "settings.label." + rawValue }
}
