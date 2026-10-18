import Foundation
import GRDB
import AlfaCalculation

struct PDFExtractedPositionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "pdf_extracted_positions"

    var pk: Int64?
    var recordID: String
    var sourceFile: String
    var pageNumber: Int
    var title: String
    var componentType: String
    var netPrice: String
    var unit: String
    var quantity: Double
    var confidence: Double
    var extractedAt: String

    init(_ p: PDFExtractedPosition) {
        pk = nil
        recordID = p.id
        sourceFile = p.sourceFile
        pageNumber = p.pageNumber
        title = p.title
        componentType = p.componentType.rawValue
        netPrice = LearningCodec.decimalString(from: p.netPrice)
        unit = p.unit
        quantity = p.quantity
        confidence = p.confidence
        extractedAt = LearningCodec.string(from: p.extractedAt)
    }

    var domain: PDFExtractedPosition {
        PDFExtractedPosition(
            id: recordID, sourceFile: sourceFile, pageNumber: pageNumber, title: title,
            componentType: ComponentType(rawValue: componentType) ?? .other,
            netPrice: LearningCodec.decimal(from: netPrice), unit: unit, quantity: quantity,
            confidence: confidence, extractedAt: LearningCodec.date(from: extractedAt))
    }
}

extension LearningDatabase {
    func insert(_ p: PDFExtractedPosition, _ db: Database) throws {
        try PDFExtractedPositionRecord(p).insert(db)
    }

    func pdfExtractedPositions() throws -> [PDFExtractedPosition] {
        try read { db in
            try PDFExtractedPositionRecord.order(Column("pk")).fetchAll(db).map(\.domain)
        }
    }

    func pdfRecordIDExists(_ recordID: String) throws -> Bool {
        try read { db in
            try PDFExtractedPositionRecord.filter(Column("recordID") == recordID).fetchCount(db) > 0
        }
    }
}

public struct PDFImportReport: Equatable, Sendable {
    public let imported: Int
    public let skippedDuplicate: Int
    public init(imported: Int, skippedDuplicate: Int) {
        self.imported = imported; self.skippedDuplicate = skippedDuplicate
    }
}

public extension LearningStore {
    @discardableResult
    func importPDFExtractedPositions(_ positions: [PDFExtractedPosition]) throws -> PDFImportReport {
        let db = try database()
        var imported = 0, skipped = 0
        for p in positions {
            if try db.pdfRecordIDExists(p.id) { skipped += 1; continue }
            try db.write { conn in
                try db.insert(p, conn)
                try db.insert(
                    LearningAuditLogEntry(
                        entityID: p.id, entityTable: "pdf_extracted_positions",
                        action: "pdf_extracted",
                        message: "PDF-Position \(p.title) extrahiert (\(p.sourceFile), S. \(p.pageNumber)) — Freigabe ausstehend."),
                    conn)
            }
            imported += 1
        }
        return PDFImportReport(imported: imported, skippedDuplicate: skipped)
    }

    func pdfExtractedPositions() throws -> [PDFExtractedPosition] {
        try database().pdfExtractedPositions()
    }

    func pendingPDFPositions() throws -> [PDFExtractedPosition] {
        let confirmed = try confirmedOfferRecordIDs()
        return try pdfExtractedPositions().filter { confirmed.contains($0.id) == false }
    }

    @discardableResult
    func confirmPDFPosition(recordID: String, note: String = "") throws -> ReviewAction {
        let db = try database()
        let action = ReviewAction(candidateID: recordID, kind: .releaseAsActiveAnchor, note: note)
        try db.write { conn in
            try db.insert(action, conn)
            try db.insert(
                LearningAuditLogEntry(
                    entityID: recordID, entityTable: "pdf_extracted_positions",
                    action: "pdf_confirmed",
                    message: "PDF-Position \(recordID) als Preis-Anker freigegeben. \(note)"),
                conn)
        }
        return action
    }

    func confirmedPDFPositions() throws -> [PDFExtractedPosition] {
        let confirmed = try confirmedOfferRecordIDs()
        return try pdfExtractedPositions().filter { confirmed.contains($0.id) }
    }
}

public struct PDFLearnedAnchorProvider: PriceAnchorProviding {
    private let store: LearningStore

    public init(store: LearningStore) { self.store = store }

    public func activeAnchors() throws -> [CandidateReleaseDecision] {
        try store.confirmedPDFPositions().compactMap { p in
            guard p.netPrice > 0 else { return nil }

            let quote = "PDF-Position \(p.title) (\(p.sourceFile), Seite \(p.pageNumber))"
            return CandidateReleaseDecision(
                candidateID: p.id,
                sourceFile: p.sourceFile,
                page: p.pageNumber,
                supplier: "Lokal extrahiert",
                project: "",
                component: p.title,
                trade: "PDF-Extraktion",
                priceNetGuess: p.netPrice,
                confidence: min(1, max(0, p.confidence)) * 0.85,
                duplicateCount: 0,
                currentStatus: "release_pdf_confirmed",
                proposedStatus: "release_pdf_confirmed",
                supersededBy: nil,
                decisionScore: p.confidence * 0.85,
                decisionReason: "pdf_extracted_locally",
                helpNeeded: "",
                title: p.title,
                evidenceQuote: quote,
                carryforwardRuleStatus: "",
                ruleSafePriceNet: nil,
                ruleNotes: "pdf_extraction_local",
                componentClass: p.componentType.calculationClass,
                sourceKind: .pdfOffer)
        }
    }
}
