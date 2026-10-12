import Foundation
import Hub

enum MailFailure {
    case transient(Hint)
    case rejected(Hint)

    var hint: Hint {
        switch self {
        case .transient(let hint), .rejected(let hint): hint
        }
    }

    var isTransient: Bool {
        if case .transient = self { return true }
        return false
    }

    @MainActor
    static func classify(_ error: Error, inlet: Inlet.ID, hub: any HubAccess) -> MailFailure {
        let classification = hub.classify(error, inlet: inlet)
        switch classification.kind {
        case .transient:
            return .transient(Hint(text: MailHintKey.offline, classification: classification))
        case .signIn:
            return .rejected(Hint(text: MailHintKey.signIn, classification: classification, fixIn: .inlet(inlet)))
        case .rejected:
            let text = classification.original.provider == "unknown" ? MailHintKey.failed : MailHintKey.rejected
            return .rejected(Hint(text: text, classification: classification))
        }
    }

    @MainActor
    static func hubError(_ error: Error, inlet: Inlet.ID, hub: any HubAccess) -> HubError {
        if let hub = error as? HubError { return hub }
        return .provider(classify(error, inlet: inlet, hub: hub).hint)
    }
}
