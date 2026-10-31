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
