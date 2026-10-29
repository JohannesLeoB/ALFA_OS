import Foundation
import Hub

@MainActor
enum DeliveryEngine {
    enum Failure {
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
    }

    enum Delivery {
        case sent
        case transient(Hint)
        case rejected(Hint)
    }

    static func classify(_ error: Error, inlet: Inlet.ID, access: any AccessPort) -> Failure {
        let classification = access.classify(error, inlet: inlet)
        switch classification.kind {
        case .transient:
            return .transient(Hint(text: MessageTextKey.offline.rawValue, classification: classification))
        case .signIn:
            return .rejected(Hint(text: Hint.signInExpiredText, classification: classification, fixIn: .inlet(inlet)))
        case .rejected:
            let text = classification.original.provider == "unknown" ? MessageTextKey.failed.rawValue : MessageTextKey.rejected.rawValue
            return .rejected(Hint(text: text, classification: classification))
        }
    }

    static func hubFailure(_ error: Error, inlet: Inlet.ID, access: any AccessPort) -> HubFailure {
        if let failure = error as? HubFailure { return failure }
        return .provider(classify(error, inlet: inlet, access: access).hint)
    }

    static func deliver(_ item: inout OutboxItem, verify: Bool, byUser: Bool, access: any AccessPort) async -> Delivery {
        let transport: any MailTransportPort
        do {
            transport = try access.port((any MailTransportPort).self, for: item.inlet)
        } catch {
            return .transient(Hint(text: MessageTextKey.offline.rawValue, detail: String(describing: error)))
        }
        if verify {
            do {
                if try await transport.wasSent(messageID: item.messageID) { return .sent }
            } catch {
                let failure = classify(error, inlet: item.inlet, access: access)
                if failure.isTransient { return .transient(failure.hint) }
                if !byUser { return .rejected(failure.hint) }
            }
        }
        var outgoing = item.draft
        outgoing.messageID = item.messageID
        do {
            if let draftID = item.draftID {
                let saved = try await transport.saveDraft(outgoing, replacing: draftID)
                item.draftID = saved.id
                item.mirrorID = saved.mirrorID
                try await transport.sendDraft(id: saved.id)
            } else {
                try await transport.send(outgoing)
            }
            return .sent
        } catch {
            switch classify(error, inlet: item.inlet, access: access) {
            case .transient(let hint): return .transient(hint)
            case .rejected(let hint): return .rejected(hint)
            }
        }
    }
}
