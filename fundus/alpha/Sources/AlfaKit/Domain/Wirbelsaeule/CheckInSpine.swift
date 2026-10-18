import Foundation

public typealias CheckInGegenstand = WorkBasket

public enum AuditKanal: Sendable, Equatable {
    case angebotImportiert

    case warenkorbGesendet

    case schaetzungAngepasst

    case checkoutAusgefuehrt

    public var auditAction: AuditEntry.Action {
        switch self {
        case .angebotImportiert:   return .offerImported
        case .warenkorbGesendet:   return .warenkorbGesendet
        case .schaetzungAngepasst: return .estimateAdjusted
        case .checkoutAusgefuehrt: return .warenkorbGesendet
        }
    }
}

public struct CheckInAbsicht: Sendable {
    public let adapterID: PortID

    public let target: PortZiel

    public let begruendung: String

    public let actorUserID: String

    public let projectNumber: String?

    public let source: String?

    public init(
        adapterID: PortID,
        target: PortZiel,
        begruendung: String,
        actorUserID: String,
        projectNumber: String? = nil,
        source: String? = nil
    ) {
        self.adapterID = adapterID
        self.target = target
        self.begruendung = begruendung
        self.actorUserID = actorUserID
        self.projectNumber = projectNumber
        self.source = source
    }
}

public struct CheckInVorschau: Sendable {
    public let vorschau: CheckoutPreview

    public let idempotenzSchluessel: String

    public let istDuplikat: Bool

    public init(
        vorschau: CheckoutPreview,
        idempotenzSchluessel: String,
        istDuplikat: Bool
    ) {
        self.vorschau = vorschau
        self.idempotenzSchluessel = idempotenzSchluessel
        self.istDuplikat = istDuplikat
    }
}

public struct CheckInAusfuehrung: Sendable {
    public let result: CheckoutResult

    public let kanal: AuditKanal

    public let summaryDetail: String?

    public init(
        result: CheckoutResult,
        kanal: AuditKanal,
        summaryDetail: String? = nil
    ) {
        self.result = result
        self.kanal = kanal
        self.summaryDetail = summaryDetail
    }
}

public struct CheckInQuittung: Sendable {
    public let result: CheckoutResult

    public let audit: AuditEntry

    public init(result: CheckoutResult, audit: AuditEntry) {
        self.result = result
        self.audit = audit
    }
}

public enum CheckInFehler: Error, Equatable, Sendable {
    case adapterUnbekannt(PortID)

    case keinRecht(PortID)

    case inhaltsArtNichtErlaubt(PortID, InhaltsArt)
}

public protocol CheckInAdapter: Sendable {
    var id: PortID { get }

    var name: String { get }

    func erlaubteInhaltsArten() -> Set<InhaltsArt>

    func idempotenzSchluessel(_ gegenstand: CheckInGegenstand, _ absicht: CheckInAbsicht) -> String

    func vorschau(_ gegenstand: CheckInGegenstand, _ absicht: CheckInAbsicht) async throws -> CheckInVorschau

    func fuehreAus(_ gegenstand: CheckInGegenstand, _ absicht: CheckInAbsicht) async throws -> CheckInAusfuehrung
}

public protocol CheckInAuditSink: Sendable {
    func schreibe(_ entry: AuditEntry) async throws
}

public struct CheckInSpine: Sendable {
    private let adapter: [PortID: any CheckInAdapter]

    private let rechte: any PortRightsProviding

    private let audit: any CheckInAuditSink

    public init(
        adapter: [any CheckInAdapter],
        rechte: any PortRightsProviding,
        audit: any CheckInAuditSink
    ) {
        var byID: [PortID: any CheckInAdapter] = [:]
        for entry in adapter { byID[entry.id] = entry }
        self.adapter = byID
        self.rechte = rechte
        self.audit = audit
    }

    public var alleAdapterIDs: Set<PortID> { Set(adapter.keys) }

    public func vorschlagen(
        _ gegenstand: CheckInGegenstand,
        _ absicht: CheckInAbsicht
    ) async throws -> CheckInVorschau {
        let zielAdapter = try pruefeUndHole(absicht, inhaltsArt: gegenstand.inhaltsArt)
        return try await zielAdapter.vorschau(gegenstand, absicht)
    }

    public func bestaetigen(
        _ gegenstand: CheckInGegenstand,
        _ absicht: CheckInAbsicht
    ) async throws -> CheckInQuittung {
        let zielAdapter = try pruefeUndHole(absicht, inhaltsArt: gegenstand.inhaltsArt)

        let vorschau = try await zielAdapter.vorschau(gegenstand, absicht)

        if vorschau.istDuplikat {
            let quittungOhneNeuenWrite = CheckoutResult(
                erfolg: true,
                referenz: vorschau.idempotenzSchluessel,
                message: "Bereits eingecheckt (Duplikat) — kein zweiter Audit."
            )
            let audit = baueAudit(
                absicht: absicht,
                kanal: .checkoutAusgefuehrt,
                summaryDetail: "Duplikat — bestehender Eintrag gilt",
                idempotenzKey: vorschau.idempotenzSchluessel
            )

            return CheckInQuittung(result: quittungOhneNeuenWrite, audit: audit)
        }

        let ausfuehrung = try await zielAdapter.fuehreAus(gegenstand, absicht)
        let entry = baueAudit(
            absicht: absicht,
            kanal: ausfuehrung.kanal,
            summaryDetail: ausfuehrung.summaryDetail,
            idempotenzKey: vorschau.idempotenzSchluessel
        )
        try await audit.schreibe(entry)
        return CheckInQuittung(result: ausfuehrung.result, audit: entry)
    }

    private func pruefeUndHole(
        _ absicht: CheckInAbsicht,
        inhaltsArt: InhaltsArt
    ) throws -> any CheckInAdapter {
        guard let zielAdapter = adapter[absicht.adapterID] else {
            throw CheckInFehler.adapterUnbekannt(absicht.adapterID)
        }
        let erlaubt = rechte.erlaubtePorts(userID: absicht.actorUserID)
        guard erlaubt.contains(absicht.adapterID) else {
            throw CheckInFehler.keinRecht(absicht.adapterID)
        }
        guard zielAdapter.erlaubteInhaltsArten().contains(inhaltsArt) else {
            throw CheckInFehler.inhaltsArtNichtErlaubt(absicht.adapterID, inhaltsArt)
        }
        return zielAdapter
    }

    private func baueAudit(
        absicht: CheckInAbsicht,
        kanal: AuditKanal,
        summaryDetail: String?,
        idempotenzKey: String
    ) -> AuditEntry {
        let summary: String
        if let detail = summaryDetail, detail.isEmpty == false {
            summary = "\(absicht.begruendung) — \(detail)"
        } else {
            summary = absicht.begruendung
        }
        return AuditEntry(
            actorUserID: absicht.actorUserID,
            projectID: absicht.projectNumber ?? "-",
            action: kanal.auditAction,
            summary: summary,
            source: absicht.source,
            idempotenzKey: idempotenzKey
        )
    }
}
