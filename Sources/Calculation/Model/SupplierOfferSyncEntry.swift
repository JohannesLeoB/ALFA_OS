import Foundation

struct SupplierOfferSyncEntry: Equatable, Identifiable, Sendable {
    let id: String
    let sourceRecordID: String
    let offerKind: SupplierOfferKind
    let netEur: Decimal
    let offerStatus: SupplierOfferStatus
    let partner: String
    let importedAt: Date
    let offerDate: String?

    init(id: String = UUID().uuidString, sourceRecordID: String, offerKind: SupplierOfferKind, netEur: Decimal, offerStatus: SupplierOfferStatus, partner: String, importedAt: Date = Date(), offerDate: String? = nil) {
        self.id = id
        self.sourceRecordID = sourceRecordID
        self.offerKind = offerKind
        self.netEur = netEur
        self.offerStatus = offerStatus
        self.partner = partner
        self.importedAt = importedAt
        self.offerDate = offerDate
    }
}
