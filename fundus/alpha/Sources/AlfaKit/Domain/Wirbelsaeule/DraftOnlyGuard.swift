import Foundation

public enum DraftOnlyGuardError: Error, Sendable, Equatable, LocalizedError {
    case verboteneAktion(IntegrationCommandAction)

    case keineFreigabe

    case freigabeAbgelaufen

    case freigabePasstNichtZuPaket

    case profilNichtSchreibbar

    case blockiertePositionen

    public var errorDescription: String? {
        switch self {
        case .verboteneAktion(let action): "🔒 Aktion \(action.rawValue) ist nicht erlaubt."
        case .keineFreigabe: "🔒 Keine Freigabe vorhanden — ein Mensch muss zuerst bestätigen."
        case .freigabeAbgelaufen: "🔒 Die Freigabe ist abgelaufen — erneut bestätigen."
        case .freigabePasstNichtZuPaket: "🔒 Die Freigabe gehört zu einem anderen Paket/einer anderen Revision."
        case .profilNichtSchreibbar: "🔒 sevdesk-Verbindung erlaubt aktuell keinen Schreibversuch."
        case .blockiertePositionen: "🔒 Mindestens eine Position braucht noch eine Review (kein Verkaufspreis)."
        }
    }
}

public enum DraftOnlyGuard {
    private static let bekannteAktionen: Set<IntegrationCommandAction> = [
        .createOfferDraft, .updateOwnOfferDraft, .refreshSevdeskStatus
    ]

    public static func assertSchreibenErlaubt(
        command: IntegrationCommand,
        package: CommercialDraftPackage,
        proof: ApprovalProof?,
        capabilityProfile: SevdeskCapabilityProfile?,
        now: Date = Date()
    ) throws {
        guard bekannteAktionen.contains(command.requestedAction) else {
            throw DraftOnlyGuardError.verboteneAktion(command.requestedAction)
        }

        guard let capabilityProfile, capabilityProfile.istFreigegebenFürWrite(now: now) else {
            throw DraftOnlyGuardError.profilNichtSchreibbar
        }

        if command.requestedAction != .refreshSevdeskStatus {
            guard let proof else { throw DraftOnlyGuardError.keineFreigabe }
            guard proof.istAbgelaufen(now: now) == false else { throw DraftOnlyGuardError.freigabeAbgelaufen }
            guard proof.passtZu(package: package) else { throw DraftOnlyGuardError.freigabePasstNichtZuPaket }
            guard package.hatBlockiertePositionen == false else { throw DraftOnlyGuardError.blockiertePositionen }
        }
    }
}
