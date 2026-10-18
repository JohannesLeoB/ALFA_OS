import Foundation

public enum AirtableOfferKind: String, Codable, CaseIterable, Sendable {
    case eingehend
    case ausgehend

    public var displayName: String {
        switch self {
        case .eingehend: "Eingehend (Lieferant → MYKILOS)"
        case .ausgehend: "Ausgehend (MYKILOS → Kunde)"
        }
    }
}

public enum AirtableOfferStatus: String, Codable, CaseIterable, Sendable {
    case entwurf
    case eingegangen
    case offen
    case akzeptiert
    case abgelehnt
    case auftrag
    case schlussrechnung

    public var displayName: String {
        switch self {
        case .entwurf: "Entwurf"
        case .eingegangen: "Eingegangen"
        case .offen: "Offen"
        case .akzeptiert: "Akzeptiert"
        case .abgelehnt: "Abgelehnt"
        case .auftrag: "Auftrag"
        case .schlussrechnung: "Schlussrechnung"
        }
    }

    public func learningReason(kind: AirtableOfferKind) -> EstimateAdjustmentReason? {
        switch (kind, self) {
        case (.eingehend, .schlussrechnung): return .finalInvoiceReceived
        case (.eingehend, .auftrag):         return .finalInvoiceReceived
        case (.eingehend, .akzeptiert):      return .realOfferReceived
        case (.ausgehend, .akzeptiert):      return .realOfferReceived
        case (.ausgehend, .auftrag):         return .realOfferReceived
        case (.ausgehend, .abgelehnt):       return .marketPrice
        default:                             return nil
        }
    }
}

public struct AirtableOfferEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let airtableRecordID: String
    public let kind: AirtableOfferKind
    public let projekt: String
    public let partner: String
    public let datum: String
    public let nettoEur: Decimal
    public let status: AirtableOfferStatus
    public let dokumentURL: String?
    public let leistungsbeschreibung: String?

    public init(
        id: String = UUID().uuidString,
        airtableRecordID: String,
        kind: AirtableOfferKind,
        projekt: String,
        partner: String,
        datum: String,
        nettoEur: Decimal,
        status: AirtableOfferStatus,
        dokumentURL: String?,
        leistungsbeschreibung: String?
    ) {
        self.id = id
        self.airtableRecordID = airtableRecordID
        self.kind = kind
        self.projekt = projekt
        self.partner = partner
        self.datum = datum
        self.nettoEur = nettoEur
        self.status = status
        self.dokumentURL = dokumentURL
        self.leistungsbeschreibung = leistungsbeschreibung
    }
}

public struct AirtableOfferSyncEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let airtableRecordID: String
    public let offerKind: AirtableOfferKind
    public let nettoEur: Decimal
    public let offerStatus: AirtableOfferStatus
    public let partner: String
    public let docSHA256: String?
    public let importedAt: Date
    public let reviewActionID: String?
    public let syncStatus: String

    public let offerDate: String?

    public init(
        id: String = UUID().uuidString,
        airtableRecordID: String,
        offerKind: AirtableOfferKind,
        nettoEur: Decimal,
        offerStatus: AirtableOfferStatus,
        partner: String,
        docSHA256: String?,
        importedAt: Date = Date(),
        reviewActionID: String?,
        syncStatus: String = "imported",
        offerDate: String? = nil
    ) {
        self.id = id
        self.airtableRecordID = airtableRecordID
        self.offerKind = offerKind
        self.nettoEur = nettoEur
        self.offerStatus = offerStatus
        self.partner = partner
        self.docSHA256 = docSHA256
        self.importedAt = importedAt
        self.reviewActionID = reviewActionID
        self.syncStatus = syncStatus
        self.offerDate = offerDate
    }
}

public struct AirtableOfferSyncReport: Equatable, Sendable {
    public let fetched: Int
    public let skippedDuplicate: Int
    public let skippedNoSignal: Int
    public let imported: Int
    public let errors: [String]

    public init(fetched: Int, skippedDuplicate: Int, skippedNoSignal: Int, imported: Int, errors: [String]) {
        self.fetched = fetched
        self.skippedDuplicate = skippedDuplicate
        self.skippedNoSignal = skippedNoSignal
        self.imported = imported
        self.errors = errors
    }

    public var summary: String {
        "\(imported) importiert, \(skippedDuplicate) Duplikat, \(skippedNoSignal) kein Learning-Signal, \(fetched) gesamt"
    }
}
