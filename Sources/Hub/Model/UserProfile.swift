import Foundation

public struct UserProfile: Equatable, Sendable {
    public var name = ""
    public var role = ""
    public var code = ""
    public var phone = ""
    public var birthdays = false

    init(name: String = "", role: String = "", code: String = "", phone: String = "", birthdays: Bool = false) {
        self.name = name
        self.role = role
        self.code = code
        self.phone = phone
        self.birthdays = birthdays
    }

    static func normalized(_ text: String, finished: Bool) -> String {
        let collapsed = collapsed(text)
        return finished ? collapsed.trimmingCharacters(in: .whitespacesAndNewlines) : collapsed
    }

    private static func collapsed(_ text: String) -> String {
        var result = ""
        var spaced = false
        for character in text {
            if character.isWhitespace {
                if !spaced { result.append(" ") }
                spaced = true
            } else {
                result.append(character)
                spaced = false
            }
        }
        return result
    }
}

public struct PrivacyChoices: Equatable, Sendable {
    public var loadImages = false
    public var assistantOff = false
    public var chatFiles = true

    public init(loadImages: Bool = false, assistantOff: Bool = false, chatFiles: Bool = true) {
        self.loadImages = loadImages
        self.assistantOff = assistantOff
        self.chatFiles = chatFiles
    }
}

public enum StartDestination: String, CaseIterable, Sendable {
    case mail
    case settings
    case lastOpen

    public var key: String { "settings.start." + rawValue }

    public var appID: String? {
        switch self {
        case .mail: "mail"
        case .settings: "settings"
        case .lastOpen: nil
        }
    }

    static func stored(_ raw: String?) -> StartDestination {
        raw.flatMap(StartDestination.init(rawValue:)) ?? .mail
    }
}

public enum LockDelay: String, CaseIterable, Sendable {
    case immediately
    case minute1
    case minutes5
    case minutes15

    public var key: String { "settings.lock.delay." + rawValue }
}

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
    static let mailStoreAttachments = "settings.mailStore.attachments"
    static let mailStoreLimit = "settings.mailStore.limit"
    static let mailStoreFolder = "settings.mailStore.folder"
    static let undoSend = "settings.mail.undoSend"

    static func companyEntry(_ id: String) -> String { "settings.company." + id }

    static func imprintEntry(_ id: String) -> String { "settings.imprint." + id }

    static let mailboxDisplayPrefix = "settings.mailbox.display."

    static func mailboxDisplay(_ inlet: String) -> String { mailboxDisplayPrefix + inlet }

    static let mailboxNamePrefix = "settings.mailbox.name."

    static func mailboxName(_ inlet: String) -> String { mailboxNamePrefix + inlet }

    static let mailboxRangePrefix = "settings.mailbox.range."

    static func mailboxRange(_ inlet: String) -> String { mailboxRangePrefix + inlet }

    static let mailboxServerCopyPrefix = "settings.mailbox.serverCopy."

    static let mailboxImagesPrefix = "settings.mailbox.images."

    static func mailboxImages(_ inlet: String) -> String { mailboxImagesPrefix + inlet }

    static func mailboxServerCopy(_ inlet: String) -> String { mailboxServerCopyPrefix + inlet }

    static let mailboxSignaturePrefix = "settings.mailbox.signature."

    static func mailboxSignature(_ inlet: String) -> String { mailboxSignaturePrefix + inlet }

    static let mailboxSignatureComposePrefix = "settings.mailbox.signatureNew."

    static func mailboxSignatureCompose(_ inlet: String) -> String { mailboxSignatureComposePrefix + inlet }

    static let mailboxSignatureAbovePrefix = "settings.mailbox.signatureAbove."

    static func mailboxSignatureAbove(_ inlet: String) -> String { mailboxSignatureAbovePrefix + inlet }

    static func contactSource(_ id: String) -> String { "settings.contacts.source." + id }

    static func contactCache(_ id: String) -> String { "contacts.cache." + id }
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

public struct Mailbox: Item, Equatable {
    public var id: String
    public var inlet: Inlet.ID
    public var name: String
    public var role: String

    public init(id: String, inlet: Inlet.ID, name: String, role: String) {
        self.id = id
        self.inlet = inlet
        self.name = name
        self.role = role
    }
}

public enum MailboxDisplay: String, CaseIterable, Sendable {
    case ownName
    case localPart
    case domain

    public func text(title: String, account: String) -> String {
        switch self {
        case .ownName:
            let name = title.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? Self.local(account) : name
        case .localPart: return Self.local(account)
        case .domain: return Self.domain(account)
        }
    }

    public func choice(title: String, account: String) -> String? {
        switch self {
        case .ownName:
            let name = title.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        case .localPart: return Self.local(account)
        case .domain: return Self.domain(account)
        }
    }

    public static func local(_ account: String) -> String {
        let part = account.split(separator: "@", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return (part.isEmpty ? account : part) + "@"
    }

    public static func domain(_ account: String) -> String {
        let parts = account.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        let part = parts.count > 1 ? String(parts[1]) : ""
        return "@" + (part.isEmpty ? account : part)
    }
}

public enum MailboxRange: String, CaseIterable, Sendable {
    case days30
    case days90
    case year
    case all

    public static let standard = MailboxRange.days30
    public static let earliest = Date(timeIntervalSince1970: 631_152_000)

    public var days: Int? {
        switch self {
        case .days30: 30
        case .days90: 90
        case .year: 365
        case .all: nil
        }
    }

    public func cutoff(from now: Date) -> Date? {
        days.map { now.addingTimeInterval(-Double($0) * 86_400) }
    }

    public func resolved(in offered: [MailboxRange]) -> MailboxRange {
        if offered.contains(self) { return self }
        return offered.contains(.standard) ? .standard : (offered.first ?? .standard)
    }

    public var key: String {
        switch self {
        case .days30: "settings.mailStore.period.d30"
        case .days90: "settings.mailStore.period.d90"
        case .year: "settings.mailStore.period.y1"
        case .all: "settings.mailStore.period.all"
        }
    }
}

public struct MailboxSignature: Equatable, Sendable {
    public var text: String
    public var onCompose: Bool
    public var aboveQuote: Bool

    public init(text: String, onCompose: Bool = true, aboveQuote: Bool = false) {
        self.text = text
        self.onCompose = onCompose
        self.aboveQuote = aboveQuote
    }

    public var block: String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var name: String? {
        block?.split(whereSeparator: \.isNewline).first.map(String.init)
    }
}

public enum ServerCopy: String, CaseIterable, Sendable {
    case keep
    case day
    case week
    case month
    case deleted

    public static let standard = ServerCopy.keep

    public var days: Int? {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        case .keep, .deleted: nil
        }
    }

    public var key: String { "settings.account.serverCopy." + rawValue }
}

public enum MailStoreLimit: String, CaseIterable, Sendable {
    case gb1
    case gb5
    case gb10
    case gb25
    case none

    public static let standard = MailStoreLimit.none

    public var bytes: Int? {
        switch self {
        case .gb1: 1_000_000_000
        case .gb5: 5_000_000_000
        case .gb10: 10_000_000_000
        case .gb25: 25_000_000_000
        case .none: nil
        }
    }

    public var key: String {
        switch self {
        case .gb1: "settings.mailStore.limit.gb1"
        case .gb5: "settings.mailStore.limit.gb5"
        case .gb10: "settings.mailStore.limit.gb10"
        case .gb25: "settings.mailStore.limit.gb25"
        case .none: "settings.mailStore.limit.none"
        }
    }
}

public enum UndoSend: String, CaseIterable, Sendable {
    case off
    case seconds10
    case seconds20
    case seconds30

    public static let standard = UndoSend.seconds10

    public var seconds: Int {
        switch self {
        case .off: 0
        case .seconds10: 10
        case .seconds20: 20
        case .seconds30: 30
        }
    }
}

public struct MailStoreSettings: Equatable, Sendable {
    public var attachments: Bool
    public var limit: MailStoreLimit
    public var folder: Data?

    public init(attachments: Bool = false, limit: MailStoreLimit = .standard, folder: Data? = nil) {
        self.attachments = attachments
        self.limit = limit
        self.folder = folder
    }
}
