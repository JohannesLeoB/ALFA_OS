import Foundation

/// What the app offers next to a notice: nothing, or a button that opens a place in the app or in the console.
public enum AssistantAction: Equatable, Sendable {
    case none
    case openConsole
    case openSettings
}

/// A notice for the person: the catalog key of its text and the button it offers.
public struct AssistantNotice: Equatable, Sendable {
    public let textKey: String
    public let action: AssistantAction

    public init(textKey: String, action: AssistantAction) {
        self.textKey = textKey
        self.action = action
    }
}

/// Turns the failures of the assistant into notices. The texts are catalog keys; the app shows them in German.
public enum AssistantMessages {
    /// Every catalog key that a notice or a button uses. The catalog must hold a German text for each.
    public static let allKeys: [String] = [
        "ki.notice.consoleLimit", "ki.notice.badRequest", "ki.notice.invalidKey", "ki.notice.noKey",
        "ki.notice.forbidden", "ki.notice.rateLimited", "ki.notice.overloaded", "ki.notice.network",
        "ki.notice.decoding", "ki.notice.cancelled", "ki.notice.imageRejected", "ki.notice.unusable",
        "ki.button.openConsole", "ki.button.openSettings",
    ]

    /// The notice of a failed call. Empty credits and a reached limit of the console both lead to the console.
    public static func notice(for error: AIError) -> AssistantNotice {
        switch error {
        case .spendLimitReached:
            return AssistantNotice(textKey: "ki.notice.consoleLimit", action: .openConsole)
        case let .badRequest(message) where isCreditsMessage(message):
            return AssistantNotice(textKey: "ki.notice.consoleLimit", action: .openConsole)
        case .badRequest, .toolConfiguration:
            return AssistantNotice(textKey: "ki.notice.badRequest", action: .none)
        case .noKey:
            return AssistantNotice(textKey: "ki.notice.noKey", action: .openSettings)
        case .invalidKey:
            return AssistantNotice(textKey: "ki.notice.invalidKey", action: .openSettings)
        case .forbidden:
            return AssistantNotice(textKey: "ki.notice.forbidden", action: .none)
        case .rateLimited:
            return AssistantNotice(textKey: "ki.notice.rateLimited", action: .none)
        case .overloaded:
            return AssistantNotice(textKey: "ki.notice.overloaded", action: .none)
        case .network:
            return AssistantNotice(textKey: "ki.notice.network", action: .none)
        case .decoding:
            return AssistantNotice(textKey: "ki.notice.decoding", action: .none)
        case .cancelled:
            return AssistantNotice(textKey: "ki.notice.cancelled", action: .none)
        case .imageRejected:
            return AssistantNotice(textKey: "ki.notice.imageRejected", action: .none)
        case .unusableAnswer:
            return AssistantNotice(textKey: "ki.notice.unusable", action: .none)
        }
    }

    /// True when a refused request says that the credits or the limit of the console are used up.
    static func isCreditsMessage(_ message: String) -> Bool {
        let text = message.lowercased()
        return text.contains("credit balance") || text.contains("spend limit")
    }
}
