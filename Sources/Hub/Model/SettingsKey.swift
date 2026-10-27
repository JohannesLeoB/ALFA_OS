enum SettingsKey {
    static let appearance = "appearance"
    static let startDestination = "settings.startView"
    static let lockOn = "settings.lock.on"
    static let lockDelay = "settings.lock.delay"
    static let loadImages = "settings.privacy.loadImages"
    static let assistantOff = "settings.privacy.assistantOff"
    static let chatFiles = "settings.privacy.chatFiles"
    static let birthdays = "settings.identity.birthdays"
    static let identityName = "settings.identity.name"
    static let identityRole = "settings.identity.role"
    static let identityCode = "settings.identity.code"
    static let identityPhone = "settings.identity.phone"
    static let legacyImportDone = "import.legacy.done"

    static func companyEntry(_ id: String) -> String { "settings.company." + id }

    static func imprintEntry(_ id: String) -> String { "settings.imprint." + id }
}

public enum CompanyEntry: String, CaseIterable, Sendable {
    case name
    case address
    case phone
    case web
    case mail

    public var key: String { "settings.company.row." + rawValue }

    var storageKey: String { SettingsKey.companyEntry(rawValue) }
}

public enum ImprintEntry: String, CaseIterable, Sendable {
    case author
    case rights
    case signature

    public var key: String { "settings.imprint.row." + rawValue }

    var storageKey: String { SettingsKey.imprintEntry(rawValue) }
}
