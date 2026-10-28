import Foundation

public enum SlotEffect: Equatable, Sendable {
    case openOverview
    case closeOverview
    case fold
    case saveDraft(UUID)
    case discardDraft(UUID)
    case send(UUID)
    case attachFile(UUID)
    case toggleFormat
    case message(Action, String)
}

public enum SlotRouter {
    public static func route(_ action: Action, front: CardRef?) -> SlotEffect? {
        switch (action, front) {
        case (.overview, _): return .openOverview
        case (.backToStack, _): return .closeOverview
        case (.foldColumn, _): return .fold
        case (.saveDraft, .draft(let id)): return .saveDraft(id)
        case (.discardDraft, .draft(let id)): return .discardDraft(id)
        case (.send, .draft(let id)): return .send(id)
        case (.attachFile, .draft(let id)): return .attachFile(id)
        case (.format, .draft): return .toggleFormat
        case (_, .message(let id)): return .message(action, id)
        default: return nil
        }
    }
}
