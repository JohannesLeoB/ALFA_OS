import Foundation

struct SupplierOffer: Equatable, Sendable {
    let sourceRecordID: String
    let kind: SupplierOfferKind
    let partner: String
    let date: String
    let netEur: Decimal
    let status: SupplierOfferStatus

    init(sourceRecordID: String, kind: SupplierOfferKind, partner: String, date: String, netEur: Decimal, status: SupplierOfferStatus) {
        self.sourceRecordID = sourceRecordID
        self.kind = kind
        self.partner = partner
        self.date = date
        self.netEur = netEur
        self.status = status
    }
}

enum SupplierOfferKind: String, CaseIterable, Sendable {
    case incoming
    case outgoing
}

enum SupplierOfferStatus: String, CaseIterable, Sendable {
    case draft
    case received
    case open
    case accepted
    case rejected
    case order
    case finalInvoice = "final_invoice"

    func learningReason(kind: SupplierOfferKind) -> AdjustmentReason? {
        switch (kind, self) {
        case (.incoming, .finalInvoice): .finalInvoiceReceived
        case (.incoming, .order): .finalInvoiceReceived
        case (.incoming, .accepted): .realOfferReceived
        case (.outgoing, .accepted): .realOfferReceived
        case (.outgoing, .order): .realOfferReceived
        case (.outgoing, .rejected): .marketPrice
        default: nil
        }
    }
}
