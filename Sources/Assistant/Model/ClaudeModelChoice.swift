public enum ClaudeModelChoice: String, CaseIterable, Sendable {
    case standard
    case sonnet
    case haiku
    case opus

    public var id: String? {
        switch self {
        case .standard: nil
        case .sonnet: ModelRouter.sonnet
        case .haiku: ModelRouter.haiku
        case .opus: ModelRouter.opus
        }
    }

    public var key: String {
        self == .standard ? "settings.value.default" : "settings.model." + rawValue
    }

    public static func stored(_ id: String?) -> ClaudeModelChoice {
        allCases.first { $0.id != nil && $0.id == id } ?? .standard
    }
}
