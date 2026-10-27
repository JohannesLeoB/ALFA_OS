public enum SettingsSection: String, CaseIterable, Sendable, Identifiable {
    case identity
    case appearance
    case companyData
    case folders
    case templates
    case integrations
    case keyInventory
    case contacts
    case privacy
    case system
    case imprint

    public var id: String { rawValue }

    var group: SettingsGroup {
        switch self {
        case .identity, .appearance: .me
        case .companyData, .folders, .templates: .company
        case .integrations, .keyInventory, .contacts: .connections
        case .privacy, .system, .imprint: .protection
        }
    }

    public var key: String { "settings.section." + rawValue }

    public var detailKey: String { "settings.section." + rawValue + ".detail" }
}

public enum SettingsGroup: String, CaseIterable, Sendable {
    case me
    case company
    case connections
    case protection

    public var key: String { "settings.group." + rawValue }

    public var symbol: String {
        switch self {
        case .me: "person"
        case .company: "building"
        case .connections: "plug"
        case .protection: "system"
        }
    }

    public var sections: [SettingsSection] { SettingsSection.allCases.filter { $0.group == self } }
}

public enum SettingsLabel: String, CaseIterable, Sendable {
    case version
    case branch
    case database
    case diagnosis

    public var key: String { "settings.label." + rawValue }
}

public enum SettingsTarget: Equatable, Codable, Sendable {
    case inlet(String)
}
