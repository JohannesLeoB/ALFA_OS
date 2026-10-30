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

    static let mailboxDisplayPrefix = "settings.mailbox.display."

    static func mailboxDisplay(_ inlet: String) -> String { mailboxDisplayPrefix + inlet }

    static let mailboxNamePrefix = "settings.mailbox.name."

    static func mailboxName(_ inlet: String) -> String { mailboxNamePrefix + inlet }

    static let mailboxRangePrefix = "settings.mailbox.range."

    static func mailboxRange(_ inlet: String) -> String { mailboxRangePrefix + inlet }

    static let mailboxSignaturePrefix = "settings.mailbox.signature."

    static func mailboxSignature(_ inlet: String) -> String { mailboxSignaturePrefix + inlet }

    static let mailboxSignatureNewPrefix = "settings.mailbox.signatureNew."

    static func mailboxSignatureNew(_ inlet: String) -> String { mailboxSignatureNewPrefix + inlet }

    static let mailboxSignatureAbovePrefix = "settings.mailbox.signatureAbove."

    static func mailboxSignatureAbove(_ inlet: String) -> String { mailboxSignatureAbovePrefix + inlet }
}

public enum CompanyEntry: String, CaseIterable, Sendable {
    case name
    case address
    case phone
    case web
    case mail

    public var key: String { "settings.company.row." + rawValue }

    public var promptKey: String { key + ".prompt" }

    var storageKey: String { SettingsKey.companyEntry(rawValue) }
}

public enum ImprintEntry: String, CaseIterable, Sendable {
    case author
    case rights
    case signature

    public var key: String { "settings.imprint.row." + rawValue }

    public var promptKey: String { key + ".prompt" }

    var storageKey: String { SettingsKey.imprintEntry(rawValue) }
}
