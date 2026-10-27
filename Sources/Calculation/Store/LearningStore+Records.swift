import Foundation
import GRDB

extension LearningStore {
    static func audit(_ db: Database, entityID: String, table: String, action: String, detail: String = "") throws {
        try StoredAuditEntry(LearningAuditEntry(entityID: entityID, entityTable: table, action: action, detail: detail)).insert(db)
    }

    static func sessions(_ db: Database) throws -> [EstimateSession] {
        try StoredSession.order(sql: "pk").fetchAll(db).map(\.domain)
    }

    static func sessionComponents(_ db: Database) throws -> [SessionComponent] {
        try StoredComponent.order(sql: "pk").fetchAll(db).map(\.domain)
    }

    static func adjustments(_ db: Database) throws -> [EstimateAdjustment] {
        try StoredAdjustment.order(sql: "pk").fetchAll(db).map(\.domain)
    }

    static func candidates(_ db: Database) throws -> [FactorCandidate] {
        try StoredCandidate.order(sql: "pk").fetchAll(db).map(\.domain)
    }

    static func factors(_ db: Database) throws -> [ActiveFactor] {
        try StoredFactor.order(sql: "pk").fetchAll(db).map(\.domain)
    }

    static func reviewActions(_ db: Database) throws -> [ReviewAction] {
        try StoredReviewAction.order(sql: "pk").fetchAll(db).map(\.domain)
    }

    static func carcassAdjustments(_ db: Database) throws -> [CarcassAdjustment] {
        try StoredCarcassAdjustment.order(sql: "pk").fetchAll(db).compactMap(\.domain)
    }

    static func offerEntries(_ db: Database) throws -> [SupplierOfferSyncEntry] {
        try StoredOfferSync.order(sql: "pk").fetchAll(db).map(\.domain)
    }

    static func pdfPositions(_ db: Database) throws -> [PdfPosition] {
        try StoredPdfPosition.order(sql: "pk").fetchAll(db).map(\.domain)
    }
}
