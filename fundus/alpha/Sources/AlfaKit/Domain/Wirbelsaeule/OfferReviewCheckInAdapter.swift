import Foundation

public struct OfferReviewCheckInAdapter: CheckInAdapter {
    public static let portID = PortID("offer-review")

    public var id: PortID { Self.portID }
    public var name: String { "Angebot in Review" }

    public init() {}

    public func erlaubteInhaltsArten() -> Set<InhaltsArt> {
        [.dokumente, .gemischt]
    }

    public func idempotenzSchluessel(
        _ gegenstand: CheckInGegenstand,
        _ absicht: CheckInAbsicht
    ) -> String {
        let label = absicht.target.parameter["angebotLabel"] ?? ""
        let projekt = absicht.projectNumber ?? gegenstand.projectNumber
        return "offer-review|" + CheckInHash.stabil("\(projekt)|\(label)")
    }

    public func vorschau(
        _ gegenstand: CheckInGegenstand,
        _ absicht: CheckInAbsicht
    ) async throws -> CheckInVorschau {
        let label = absicht.target.parameter["angebotLabel"] ?? "Eingangsangebot"
        return CheckInVorschau(
            vorschau: CheckoutPreview(zusammenfassung: "Angebot \(label) in Review übernehmen"),
            idempotenzSchluessel: idempotenzSchluessel(gegenstand, absicht),
            istDuplikat: false
        )
    }

    public func fuehreAus(
        _ gegenstand: CheckInGegenstand,
        _ absicht: CheckInAbsicht
    ) async throws -> CheckInAusfuehrung {
        CheckInAusfuehrung(
            result: CheckoutResult(erfolg: true, referenz: nil, message: "in Review übernommen"),
            kanal: .angebotImportiert,
            summaryDetail: nil
        )
    }
}
