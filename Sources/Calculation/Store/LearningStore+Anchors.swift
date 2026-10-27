import Foundation
import GRDB

extension LearningStore {
    static func baseConfidence(for reason: AdjustmentReason) -> Double {
        switch reason {
        case .finalInvoiceReceived: 0.9
        case .realOfferReceived: 0.75
        default: 0.6
        }
    }

    @discardableResult
    func syncOffers(_ offers: [SupplierOffer]) throws -> SupplierOfferSyncReport {
        var imported = 0, skippedDuplicate = 0, skippedNoSignal = 0
        var errors: [String] = []

        for offer in offers {
            guard offer.kind == .incoming, offer.status.learningReason(kind: offer.kind) != nil else {
                skippedNoSignal += 1
                continue
            }
            do {
                let sourceRecordID = offer.sourceRecordID
                let exists = try database.read { db in
                    try StoredOfferSync.filter(Column("sourceRecordID") == sourceRecordID).fetchCount(db) > 0
                }
                if exists {
                    skippedDuplicate += 1
                    continue
                }
                let entry = SupplierOfferSyncEntry(
                    sourceRecordID: offer.sourceRecordID,
                    offerKind: offer.kind,
                    netEur: offer.netEur,
                    offerStatus: offer.status,
                    partner: offer.partner,
                    offerDate: offer.date
                )
                try database.write { db in
                    try StoredOfferSync(entry).insert(db)
                    try Self.audit(db, entityID: entry.id, table: "supplier_offer_sync", action: "offer_imported", detail: offer.partner)
                }
                imported += 1
            } catch {
                errors.append("\(offer.sourceRecordID): \(error)")
            }
        }
        return SupplierOfferSyncReport(
            fetched: offers.count,
            skippedDuplicate: skippedDuplicate,
            skippedNoSignal: skippedNoSignal,
            imported: imported,
            errors: errors
        )
    }

    func confirmOffer(sourceRecordID: String, note: String = "") throws {
        let action = ReviewAction(candidateID: sourceRecordID, kind: .releaseAsActiveAnchor, note: note)
        try database.write { db in
            try StoredReviewAction(action).insert(db)
            try Self.audit(db, entityID: sourceRecordID, table: "supplier_offer_sync", action: "offer_confirmed", detail: note)
        }
    }

    func pendingOffers() throws -> [SupplierOfferSyncEntry] {
        let confirmed = try confirmedRecordIDs()
        return try offerEntries().filter { !confirmed.contains($0.sourceRecordID) }
    }

    func confirmedOffers() throws -> [SupplierOfferSyncEntry] {
        let confirmed = try confirmedRecordIDs()
        return try offerEntries().filter { confirmed.contains($0.sourceRecordID) }
    }

    @discardableResult
    func importPdfPositions(_ positions: [PdfPosition]) throws -> PdfImportReport {
        var imported = 0, skipped = 0
        for position in positions {
            let positionID = position.id
            let exists = try database.read { db in
                try StoredPdfPosition.filter(Column("recordID") == positionID).fetchCount(db) > 0
            }
            if exists { skipped += 1; continue }
            try database.write { db in
                try StoredPdfPosition(position).insert(db)
                try Self.audit(db, entityID: position.id, table: "pdf_extracted_positions", action: "pdf_extracted", detail: position.sourceFile)
            }
            imported += 1
        }
        return PdfImportReport(imported: imported, skippedDuplicate: skipped)
    }

    func pendingPdfPositions() throws -> [PdfPosition] {
        let confirmed = try confirmedRecordIDs()
        return try pdfPositions().filter { confirmed.contains($0.id) == false }
    }

    func confirmPdfPosition(recordID: String, note: String = "") throws {
        let action = ReviewAction(candidateID: recordID, kind: .releaseAsActiveAnchor, note: note)
        try database.write { db in
            try StoredReviewAction(action).insert(db)
            try Self.audit(db, entityID: recordID, table: "pdf_extracted_positions", action: "pdf_confirmed", detail: note)
        }
    }

    func confirmedPdfPositions() throws -> [PdfPosition] {
        let confirmed = try confirmedRecordIDs()
        return try pdfPositions().filter { confirmed.contains($0.id) }
    }

    private func confirmedRecordIDs() throws -> Set<String> {
        let actions = try database.read { db in try Self.reviewActions(db) }
        return Set(actions.filter { $0.kind == .releaseAsActiveAnchor }.map(\.candidateID))
    }

    private func offerEntries() throws -> [SupplierOfferSyncEntry] {
        try database.read { db in try Self.offerEntries(db) }
    }

    private func pdfPositions() throws -> [PdfPosition] {
        try database.read { db in try Self.pdfPositions(db) }
    }
}

struct PdfImportReport: Equatable, Sendable {
    let imported: Int
    let skippedDuplicate: Int
}

struct SupplierOfferSyncReport: Equatable, Sendable {
    let fetched: Int
    let skippedDuplicate: Int
    let skippedNoSignal: Int
    let imported: Int
    let errors: [String]
}
