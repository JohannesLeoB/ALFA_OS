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
