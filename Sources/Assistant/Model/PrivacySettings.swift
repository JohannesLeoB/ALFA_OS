import Hub

public enum PrivacyCategory: String, CaseIterable, Codable, Sendable, Equatable {
    case mail
    case calendar
    case contacts
    case drive
    case clickUp
    case notes
    case tasks
    case catalogCalculation
    case studioKnowledge
    case chat
    case time

    public var key: String {
        switch self {
        case .mail: "settings.privacy.category.mail"
        case .calendar: "settings.privacy.category.calendar"
        case .contacts: "settings.privacy.category.contacts"
        case .drive: "settings.privacy.category.drive"
        case .clickUp: "settings.privacy.category.clickUp"
        case .notes: "settings.privacy.category.notes"
        case .tasks: "settings.privacy.category.tasks"
        case .catalogCalculation: "settings.privacy.category.catalogCalculation"
        case .studioKnowledge: "settings.privacy.category.studioKnowledge"
        case .chat: "settings.privacy.category.chat"
        case .time: "settings.privacy.category.time"
        }
    }
}

public struct PrivacySettings: Codable, Equatable, Sendable {
    public var disabled: Set<PrivacyCategory>

    public init(disabled: Set<PrivacyCategory> = []) {
        self.disabled = disabled
    }

    public func shares(_ category: PrivacyCategory) -> Bool {
        disabled.contains(category) == false
    }
}

public struct PrivacySnapshot: Sendable, Equatable {
    var choices: PrivacyChoices
    var settings: PrivacySettings

    public init(choices: PrivacyChoices = PrivacyChoices(), settings: PrivacySettings = PrivacySettings()) {
        self.choices = choices
        self.settings = settings
    }

    var assistantOff: Bool { choices.assistantOff }
    var chatFiles: Bool { choices.chatFiles }

    func shares(_ category: PrivacyCategory) -> Bool {
        settings.shares(category)
    }
}
