import Foundation
import Hub

extension InboxState {
    public func signatureName(_ id: UUID) -> String? {
        draft(id).flatMap { signatures($0.inlet)?.name }
    }

    public func signatureApplied(_ id: UUID) -> Bool {
        draft(id)?.draft.signed != nil
    }

    public func useSignature(_ id: UUID, _ on: Bool) {
        guard let card = draft(id) else { return }
        let signature = signatures(card.inlet)
        edit(id) {
            $0.signatureOff = !on
            $0.resign(to: signature, explicit: on)
        }
    }
}
