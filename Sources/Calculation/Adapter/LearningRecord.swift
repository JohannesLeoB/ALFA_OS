import Foundation
import GRDB

enum LearningRecord {
    private static let posix = Locale(identifier: "en_US_POSIX")

    static func string(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    static func date(from string: String) -> Date {
        ISO8601DateFormatter().date(from: string) ?? Date(timeIntervalSince1970: 0)
    }

    static func decimalString(from value: Decimal) -> String {
        value.description
    }

    static func decimal(from string: String) -> Decimal {
        Decimal(string: string, locale: posix) ?? .zero
    }

    static func optionalDecimalString(from value: Decimal?) -> String? {
        value.map { $0.description }
    }

    static func optionalDecimal(from string: String?) -> Decimal? {
        guard let string else { return nil }
        return Decimal(string: string, locale: posix)
    }

    static func json(from array: [String]) -> String {
        guard let data = try? JSONEncoder().encode(array) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    static func stringArray(from string: String) -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(string.utf8))) ?? []
    }

    static func jsonDoubleMap(from map: [String: Double]) -> String {
        guard let data = try? JSONEncoder().encode(map) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    static func doubleMap(from string: String) -> [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: Data(string.utf8))) ?? [:]
    }
}

struct StoredSession: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "estimate_sessions" }
    var pk: Int64?
    var recordID: String
    var createdAt: String
    var requestText: String
    var baseLowNet: String
    var baseMidNet: String
    var baseHighNet: String
    var laborValueNet: String
    var evidenceIDs: String
    var status: String

    init(_ s: EstimateSession) {
        recordID = s.id
        createdAt = LearningRecord.string(from: s.createdAt)
        requestText = s.requestText
        baseLowNet = LearningRecord.decimalString(from: s.baseLowNet)
        baseMidNet = LearningRecord.decimalString(from: s.baseMidNet)
        baseHighNet = LearningRecord.decimalString(from: s.baseHighNet)
        laborValueNet = LearningRecord.decimalString(from: s.laborValueNet)
        evidenceIDs = LearningRecord.json(from: s.evidenceIDs)
        status = s.status.rawValue
    }

    var domain: EstimateSession {
        EstimateSession(
            id: recordID,
            createdAt: LearningRecord.date(from: createdAt),
            requestText: requestText,
            baseLowNet: LearningRecord.decimal(from: baseLowNet),
            baseMidNet: LearningRecord.decimal(from: baseMidNet),
            baseHighNet: LearningRecord.decimal(from: baseHighNet),
            laborValueNet: LearningRecord.decimal(from: laborValueNet),
            evidenceIDs: LearningRecord.stringArray(from: evidenceIDs),
            status: LearningStatus(rawValue: status) ?? .active
        )
    }
}

struct StoredComponent: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "estimate_session_components" }
    var pk: Int64?
    var recordID: String
    var sessionID: String
    var componentIndex: Int
    var componentClass: String
    var componentType: String
    var adjustmentTarget: String
    var baseLowNet: String
    var baseMidNet: String
    var baseHighNet: String
    var evidenceIDs: String

    init(_ c: SessionComponent) {
        recordID = c.id
        sessionID = c.sessionID
        componentIndex = c.componentIndex
        componentClass = c.componentClass.rawValue
        componentType = c.componentType.rawValue
        adjustmentTarget = c.adjustmentTarget.rawValue
        baseLowNet = LearningRecord.decimalString(from: c.baseLowNet)
        baseMidNet = LearningRecord.decimalString(from: c.baseMidNet)
        baseHighNet = LearningRecord.decimalString(from: c.baseHighNet)
        evidenceIDs = LearningRecord.json(from: c.evidenceIDs)
    }

    var domain: SessionComponent {
        SessionComponent(
            id: recordID,
            sessionID: sessionID,
            componentIndex: componentIndex,
            componentClass: ComponentClass(rawValue: componentClass) ?? .unknownReview,
            componentType: ComponentType(rawValue: componentType) ?? .baseCabinetRun,
            adjustmentTarget: AdjustmentTarget(rawValue: adjustmentTarget) ?? .wholeEstimate,
            baseLowNet: LearningRecord.decimal(from: baseLowNet),
            baseMidNet: LearningRecord.decimal(from: baseMidNet),
            baseHighNet: LearningRecord.decimal(from: baseHighNet),
            evidenceIDs: LearningRecord.stringArray(from: evidenceIDs)
        )
    }
}

struct StoredAdjustment: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "estimate_adjustments" }
    var pk: Int64?
    var recordID: String
    var sessionID: String
    var createdAt: String
    var percentDelta: Double
    var euroDelta: String?
    var adjustedMidNet: String
    var reason: String
    var target: String
    var status: String
    var note: String

    init(_ a: EstimateAdjustment) {
        recordID = a.id
        sessionID = a.sessionID
        createdAt = LearningRecord.string(from: a.createdAt)
        percentDelta = a.percentDelta
        euroDelta = LearningRecord.optionalDecimalString(from: a.euroDelta)
        adjustedMidNet = LearningRecord.decimalString(from: a.adjustedMidNet)
        reason = a.reason.rawValue
        target = a.target.rawValue
        status = a.status.rawValue
        note = a.note
    }

    var domain: EstimateAdjustment {
        EstimateAdjustment(
            id: recordID,
            sessionID: sessionID,
            createdAt: LearningRecord.date(from: createdAt),
            percentDelta: percentDelta,
            euroDelta: LearningRecord.optionalDecimal(from: euroDelta),
            adjustedMidNet: LearningRecord.decimal(from: adjustedMidNet),
            reason: AdjustmentReason(rawValue: reason) ?? .materialUnderestimated,
            target: AdjustmentTarget(rawValue: target) ?? .wholeEstimate,
            status: LearningStatus(rawValue: status) ?? .active,
            note: note
        )
    }
}

struct StoredAdjustmentTarget: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "estimate_adjustment_component_targets" }
    var pk: Int64?
    var recordID: String
    var adjustmentID: String
    var sessionComponentID: String?
    var target: String
    var percentDelta: Double
    var status: String

    init(_ t: ComponentAdjustmentTarget) {
        recordID = t.id
        adjustmentID = t.adjustmentID
        sessionComponentID = t.sessionComponentID
        target = t.target.rawValue
        percentDelta = t.percentDelta
        status = t.status.rawValue
    }
}

struct StoredCandidate: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "calibration_factor_candidates" }
    var pk: Int64?
    var recordID: String
    var createdAt: String
    var reason: String
    var target: String
    var sampleCount: Int
    var weightedPercentDelta: Double
    var multiplier: String
    var adjustmentIDs: String
    var status: String
    var note: String

    init(_ c: FactorCandidate) {
        recordID = c.id
        createdAt = LearningRecord.string(from: c.createdAt)
        reason = c.reason.rawValue
        target = c.target.rawValue
        sampleCount = c.sampleCount
        weightedPercentDelta = c.weightedPercentDelta
        multiplier = LearningRecord.decimalString(from: c.multiplier)
        adjustmentIDs = LearningRecord.json(from: c.adjustmentIDs)
        status = c.status.rawValue
        note = c.note.json
    }

    var domain: FactorCandidate {
        FactorCandidate(
            id: recordID,
            createdAt: LearningRecord.date(from: createdAt),
            reason: AdjustmentReason(rawValue: reason) ?? .materialUnderestimated,
            target: AdjustmentTarget(rawValue: target) ?? .wholeEstimate,
            sampleCount: sampleCount,
            weightedPercentDelta: weightedPercentDelta,
            multiplier: LearningRecord.decimal(from: multiplier),
            adjustmentIDs: LearningRecord.stringArray(from: adjustmentIDs),
            status: LearningStatus(rawValue: status) ?? .candidate,
            note: Notice(json: note) ?? Notice("")
        )
    }
}

struct StoredFactor: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "active_calibration_factors" }
    var pk: Int64?
    var recordID: String
    var candidateID: String
    var createdAt: String
    var reason: String
    var target: String
    var multiplier: String
    var weightedPercentDelta: Double
    var sampleCount: Int
    var status: String

    init(_ f: ActiveFactor) {
        recordID = f.id
        candidateID = f.candidateID
        createdAt = LearningRecord.string(from: f.createdAt)
        reason = f.reason.rawValue
        target = f.target.rawValue
        multiplier = LearningRecord.decimalString(from: f.multiplier)
        weightedPercentDelta = f.weightedPercentDelta
        sampleCount = f.sampleCount
        status = f.status.rawValue
    }

    var domain: ActiveFactor {
        ActiveFactor(
            id: recordID,
            candidateID: candidateID,
            createdAt: LearningRecord.date(from: createdAt),
            reason: AdjustmentReason(rawValue: reason) ?? .materialUnderestimated,
            target: AdjustmentTarget(rawValue: target) ?? .wholeEstimate,
            multiplier: LearningRecord.decimal(from: multiplier),
            weightedPercentDelta: weightedPercentDelta,
            sampleCount: sampleCount,
            status: LearningStatus(rawValue: status) ?? .active
        )
    }
}

struct StoredAuditEntry: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "learning_audit_log" }
    var pk: Int64?
    var recordID: String
    var createdAt: String
    var entityID: String
    var entityTable: String
    var action: String
    var detail: String

    init(_ e: LearningAuditEntry) {
        recordID = e.id
        createdAt = LearningRecord.string(from: e.createdAt)
        entityID = e.entityID
        entityTable = e.entityTable
        action = e.action
        detail = e.detail
    }
}

struct StoredReviewAction: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "review_actions" }
    var pk: Int64?
    var recordID: String
    var createdAt: String
    var candidateID: String
    var kind: String
    var note: String

    init(_ r: ReviewAction) {
        recordID = r.id.uuidString
        createdAt = LearningRecord.string(from: r.createdAt)
        candidateID = r.candidateID
        kind = r.kind.rawValue
        note = r.note
    }

    var domain: ReviewAction {
        ReviewAction(
            id: UUID(uuidString: recordID) ?? UUID(),
            createdAt: LearningRecord.date(from: createdAt),
            candidateID: candidateID,
            kind: ReviewActionKind(rawValue: kind) ?? .addUserNote,
            note: note
        )
    }
}

struct StoredCarcassSnapshot: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "carcass_session_snapshots" }
    var pk: Int64?
    var recordID: String
    var sessionID: String
    var snapshotJSON: String
    var createdAt: String

    init(sessionID: String, snapshot: [String: Double], createdAt: Date = Date()) {
        recordID = UUID().uuidString
        self.sessionID = sessionID
        snapshotJSON = LearningRecord.jsonDoubleMap(from: snapshot)
        self.createdAt = LearningRecord.string(from: createdAt)
    }

    var snapshot: [String: Double] { LearningRecord.doubleMap(from: snapshotJSON) }
}

struct StoredCarcassAdjustment: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "carcass_adjustments" }
    var pk: Int64?
    var recordID: String
    var sessionID: String
    var createdAt: String
    var key: String
    var modelValue: Double
    var observedValue: Double
    var reason: String
    var note: String
    var status: String

    init(_ a: CarcassAdjustment) {
        recordID = a.id
        sessionID = a.sessionID
        createdAt = LearningRecord.string(from: a.createdAt)
        key = a.target.key
        modelValue = a.modelValue
        observedValue = a.observedValue
        reason = a.reason.rawValue
        note = a.note
        status = a.status.rawValue
    }

    var domain: CarcassAdjustment? {
        guard let target = CarcassCalibrationTarget(key: key) else { return nil }
        return CarcassAdjustment(
            id: recordID, sessionID: sessionID, createdAt: LearningRecord.date(from: createdAt),
            target: target, modelValue: modelValue, observedValue: observedValue,
            reason: AdjustmentReason(rawValue: reason) ?? .materialUnderestimated,
            note: note, status: LearningStatus(rawValue: status) ?? .active)
    }
}

struct StoredCarcassCandidate: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "carcass_calibration_candidates" }
    var pk: Int64?
    var recordID: String
    var createdAt: String
    var key: String
    var sampleCount: Int
    var weightedPercentDelta: Double
    var currentValue: Double
    var proposedValue: Double
    var adjustmentIDs: String
    var status: String
    var note: String

    init(_ c: CarcassCalibrationCandidate) {
        recordID = c.id
        createdAt = LearningRecord.string(from: c.createdAt)
        key = c.target.key
        sampleCount = c.sampleCount
        weightedPercentDelta = c.weightedPercentDelta
        currentValue = c.currentValue
        proposedValue = c.proposedValue
        adjustmentIDs = LearningRecord.json(from: c.adjustmentIDs)
        status = c.status.rawValue
        note = c.note.json
    }
}

struct StoredOfferSync: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "supplier_offer_sync" }
    var pk: Int64?
    var recordID: String
    var sourceRecordID: String
    var offerKind: String
    var netEur: String
    var offerStatus: String
    var partner: String
    var importedAt: String
    var offerDate: String?

    init(_ e: SupplierOfferSyncEntry) {
        recordID = e.id
        sourceRecordID = e.sourceRecordID
        offerKind = e.offerKind.rawValue
        netEur = LearningRecord.decimalString(from: e.netEur)
        offerStatus = e.offerStatus.rawValue
        partner = e.partner
        importedAt = LearningRecord.string(from: e.importedAt)
        offerDate = e.offerDate
    }

    var domain: SupplierOfferSyncEntry {
        SupplierOfferSyncEntry(
            id: recordID,
            sourceRecordID: sourceRecordID,
            offerKind: SupplierOfferKind(rawValue: offerKind) ?? .incoming,
            netEur: LearningRecord.decimal(from: netEur),
            offerStatus: SupplierOfferStatus(rawValue: offerStatus) ?? .open,
            partner: partner,
            importedAt: LearningRecord.date(from: importedAt),
            offerDate: offerDate
        )
    }
}

struct StoredPdfPosition: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "pdf_extracted_positions" }
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

    init(_ p: PdfPosition) {
        recordID = p.id
        sourceFile = p.sourceFile
        pageNumber = p.pageNumber
        title = p.title
        componentType = p.componentType.rawValue
        netPrice = LearningRecord.decimalString(from: p.netPrice)
        unit = p.unit
        quantity = p.quantity
        confidence = p.confidence
        extractedAt = LearningRecord.string(from: p.extractedAt)
    }

    var domain: PdfPosition {
        PdfPosition(
            id: recordID, sourceFile: sourceFile, pageNumber: pageNumber, title: title,
            componentType: ComponentType(rawValue: componentType) ?? .other,
            netPrice: LearningRecord.decimal(from: netPrice), unit: unit, quantity: quantity,
            confidence: confidence, extractedAt: LearningRecord.date(from: extractedAt))
    }
}
