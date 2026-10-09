import Foundation

/// What the user may change on top of a stage. Nil or empty means the stage decides.
public struct AssistantOverrides: Sendable, Equatable {
    /// The bounds of the values, as the platform takes them.
    public static let toolRoundsRange = 1...16
    public static let searchRange = 1...20
    public static let maxTokensFloor = 1024
    /// The largest answer when the models list does not say the limit of a model.
    public static let maxTokensCeiling = 64000
    /// Below this answer length, a thinking model may run out of room before it answers.
    public static let thinkingAnswerFloor = 4096
    public static let domainLimit = 100

    public var tier: AssistantTier
    /// The model of a task by its kind. A missing or blank name means the stage picks the model of the family.
    public var models: [AITaskKind: String]
    public var effort: AIEffort?
    /// Nil means the stage picks the thinking mode; a value is sent only where the model takes it.
    public var thinking: AIThinking?
    public var maxTokens: Int?
    public var toolRounds: Int?
    /// Nil means the stage decides whether the web search runs.
    public var webSearch: Bool?
    public var searchesPerMessage: Int?
    public var allowedDomains: [String]
    public var blockedDomains: [String]
    /// Two capital letters, such as "DE". Any other text is dropped and reported.
    public var countryCode: String?
    public var timeZone: String?
    public var cache: AICachePolicy?
    /// Nil means the stage decides whether the names come back in a fixed JSON form.
    public var structuredNames: Bool?

    public init(tier: AssistantTier = .normal) {
        self.tier = tier
        self.models = [:]
        self.effort = nil
        self.thinking = nil
        self.maxTokens = nil
        self.toolRounds = nil
        self.webSearch = nil
        self.searchesPerMessage = nil
        self.allowedDomains = []
        self.blockedDomains = []
        self.countryCode = nil
        self.timeZone = nil
        self.cache = nil
        self.structuredNames = nil
    }
}

/// A value that was changed to fit the rules of the platform. The app shows it next to the setting.
public enum SettingNotice: Sendable, Equatable {
    /// The effort is the highest one that the model takes, below the one asked for.
    case effortLowered(model: String, to: AIEffort)
    /// The thinking mode does not fit the model, so the platform decides.
    case thinkingLeftToPlatform(model: String)
    /// The answer length is kept within the bounds of the model.
    case maxTokensLimited(model: String, to: Int)
    /// A short answer with thinking on may run out of room before the answer.
    case shortAnswerWithThinking(model: String)
    case toolRoundsLimited(to: Int)
    case searchesLimited(to: Int)
    /// Allowed and blocked domains are never sent together; the blocked ones are dropped.
    case blockedDomainsDropped
    case countryDropped
}
