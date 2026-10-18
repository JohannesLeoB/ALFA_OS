import Foundation
import CryptoKit
import GRDB
import AlfaCalculation

enum LearningCodec {
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
        guard let data = try? JSONEncoder().encode(array),
              let text = String(data: data, encoding: .utf8) else { return "[]" }
        return text
    }

    static func stringArray(from string: String) -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(string.utf8))) ?? []
    }

    static func jsonDoubleMap(from map: [String: Double]) -> String {
        guard let data = try? JSONEncoder().encode(map),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    static func doubleMap(from string: String) -> [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: Data(string.utf8))) ?? [:]
    }

    static func fileStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = posix
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}

struct SessionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "estimate_sessions"
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
        pk = nil
        recordID = s.id
        createdAt = LearningCodec.string(from: s.createdAt)
        requestText = s.requestText
        baseLowNet = LearningCodec.decimalString(from: s.baseLowNet)
        baseMidNet = LearningCodec.decimalString(from: s.baseMidNet)
        baseHighNet = LearningCodec.decimalString(from: s.baseHighNet)
        laborValueNet = LearningCodec.decimalString(from: s.laborValueNet)
        evidenceIDs = LearningCodec.json(from: s.evidenceIDs)
        status = s.status.rawValue
    }

    var domain: EstimateSession {
        EstimateSession(
            id: recordID,
            createdAt: LearningCodec.date(from: createdAt),
            requestText: requestText,
            baseLowNet: LearningCodec.decimal(from: baseLowNet),
            baseMidNet: LearningCodec.decimal(from: baseMidNet),
            baseHighNet: LearningCodec.decimal(from: baseHighNet),
            laborValueNet: LearningCodec.decimal(from: laborValueNet),
            evidenceIDs: LearningCodec.stringArray(from: evidenceIDs),
            status: LearningRecordStatus(rawValue: status) ?? .active
        )
    }
}

struct ComponentRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "estimate_session_components"
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

    init(_ c: EstimateSessionComponent) {
        pk = nil
        recordID = c.id
        sessionID = c.sessionID
        componentIndex = c.componentIndex
        componentClass = c.componentClass.rawValue
        componentType = c.componentType.rawValue
        adjustmentTarget = c.adjustmentTarget.rawValue
        baseLowNet = LearningCodec.decimalString(from: c.baseLowNet)
        baseMidNet = LearningCodec.decimalString(from: c.baseMidNet)
        baseHighNet = LearningCodec.decimalString(from: c.baseHighNet)
        evidenceIDs = LearningCodec.json(from: c.evidenceIDs)
    }

    var domain: EstimateSessionComponent {
        EstimateSessionComponent(
            id: recordID,
            sessionID: sessionID,
            componentIndex: componentIndex,
            componentClass: CalculationComponentClass(rawValue: componentClass) ?? .unknownReview,
            componentType: ComponentType(rawValue: componentType) ?? .baseCabinetRun,
            adjustmentTarget: EstimateAdjustmentTarget(rawValue: adjustmentTarget) ?? .wholeEstimate,
            baseLowNet: LearningCodec.decimal(from: baseLowNet),
            baseMidNet: LearningCodec.decimal(from: baseMidNet),
            baseHighNet: LearningCodec.decimal(from: baseHighNet),
            evidenceIDs: LearningCodec.stringArray(from: evidenceIDs)
        )
    }
}

struct AdjustmentRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "estimate_adjustments"
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
        pk = nil
        recordID = a.id
        sessionID = a.sessionID
        createdAt = LearningCodec.string(from: a.createdAt)
        percentDelta = a.percentDelta
        euroDelta = LearningCodec.optionalDecimalString(from: a.euroDelta)
        adjustedMidNet = LearningCodec.decimalString(from: a.adjustedMidNet)
        reason = a.reason.rawValue
        target = a.target.rawValue
        status = a.status.rawValue
        note = a.note
    }

    var domain: EstimateAdjustment {
        EstimateAdjustment(
            id: recordID,
            sessionID: sessionID,
            createdAt: LearningCodec.date(from: createdAt),
            percentDelta: percentDelta,
            euroDelta: LearningCodec.optionalDecimal(from: euroDelta),
            adjustedMidNet: LearningCodec.decimal(from: adjustedMidNet),
            reason: EstimateAdjustmentReason(rawValue: reason) ?? .materialUnderestimated,
            target: EstimateAdjustmentTarget(rawValue: target) ?? .wholeEstimate,
            status: LearningRecordStatus(rawValue: status) ?? .active,
            note: note
        )
    }
}

struct AdjustmentTargetRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "estimate_adjustment_component_targets"
    var pk: Int64?
    var recordID: String
    var adjustmentID: String
    var sessionComponentID: String?
    var target: String
    var percentDelta: Double
    var status: String

    init(_ t: EstimateAdjustmentComponentTarget) {
        pk = nil
        recordID = t.id
        adjustmentID = t.adjustmentID
        sessionComponentID = t.sessionComponentID
        target = t.target.rawValue
        percentDelta = t.percentDelta
        status = t.status.rawValue
    }

    var domain: EstimateAdjustmentComponentTarget {
        EstimateAdjustmentComponentTarget(
            id: recordID,
            adjustmentID: adjustmentID,
            sessionComponentID: sessionComponentID,
            target: EstimateAdjustmentTarget(rawValue: target) ?? .wholeEstimate,
            percentDelta: percentDelta,
            status: LearningRecordStatus(rawValue: status) ?? .active
        )
    }
}

struct CandidateRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "calibration_factor_candidates"
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

    init(_ c: CalibrationFactorCandidate) {
        pk = nil
        recordID = c.id
        createdAt = LearningCodec.string(from: c.createdAt)
        reason = c.reason.rawValue
        target = c.target.rawValue
        sampleCount = c.sampleCount
        weightedPercentDelta = c.weightedPercentDelta
        multiplier = LearningCodec.decimalString(from: c.multiplier)
        adjustmentIDs = LearningCodec.json(from: c.adjustmentIDs)
        status = c.status.rawValue
        note = c.note
    }

    var domain: CalibrationFactorCandidate {
        CalibrationFactorCandidate(
            id: recordID,
            createdAt: LearningCodec.date(from: createdAt),
            reason: EstimateAdjustmentReason(rawValue: reason) ?? .materialUnderestimated,
            target: EstimateAdjustmentTarget(rawValue: target) ?? .wholeEstimate,
            sampleCount: sampleCount,
            weightedPercentDelta: weightedPercentDelta,
            multiplier: LearningCodec.decimal(from: multiplier),
            adjustmentIDs: LearningCodec.stringArray(from: adjustmentIDs),
            status: LearningRecordStatus(rawValue: status) ?? .candidate,
            note: note
        )
    }
}

struct FactorRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "active_calibration_factors"
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

    init(_ f: ActiveCalibrationFactor) {
        pk = nil
        recordID = f.id
        candidateID = f.candidateID
        createdAt = LearningCodec.string(from: f.createdAt)
        reason = f.reason.rawValue
        target = f.target.rawValue
        multiplier = LearningCodec.decimalString(from: f.multiplier)
        weightedPercentDelta = f.weightedPercentDelta
        sampleCount = f.sampleCount
        status = f.status.rawValue
    }

    var domain: ActiveCalibrationFactor {
        ActiveCalibrationFactor(
            id: recordID,
            candidateID: candidateID,
            createdAt: LearningCodec.date(from: createdAt),
            reason: EstimateAdjustmentReason(rawValue: reason) ?? .materialUnderestimated,
            target: EstimateAdjustmentTarget(rawValue: target) ?? .wholeEstimate,
            multiplier: LearningCodec.decimal(from: multiplier),
            weightedPercentDelta: weightedPercentDelta,
            sampleCount: sampleCount,
            status: LearningRecordStatus(rawValue: status) ?? .active
        )
    }
}

struct LearningAuditRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "learning_audit_log"
    var pk: Int64?
    var recordID: String
    var createdAt: String
    var entityID: String
    var entityTable: String
    var action: String
    var message: String

    init(_ e: LearningAuditLogEntry) {
        pk = nil
        recordID = e.id
        createdAt = LearningCodec.string(from: e.createdAt)
        entityID = e.entityID
        entityTable = e.entityTable
        action = e.action
        message = e.message
    }

    var domain: LearningAuditLogEntry {
        LearningAuditLogEntry(
            id: recordID,
            createdAt: LearningCodec.date(from: createdAt),
            entityID: entityID,
            entityTable: entityTable,
            action: action,
            message: message
        )
    }
}

struct ReviewActionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "review_actions"
    var pk: Int64?
    var recordID: String
    var createdAt: String
    var candidateID: String
    var kind: String
    var note: String
    var correctedPrice: String?
    var supersededBy: String?

    init(_ r: ReviewAction) {
        pk = nil
        recordID = r.id.uuidString
        createdAt = LearningCodec.string(from: r.createdAt)
        candidateID = r.candidateID
        kind = r.kind.rawValue
        note = r.note
        correctedPrice = LearningCodec.optionalDecimalString(from: r.correctedPrice)
        supersededBy = r.supersededBy
    }

    var domain: ReviewAction {
        ReviewAction(
            id: UUID(uuidString: recordID) ?? UUID(),
            createdAt: LearningCodec.date(from: createdAt),
            candidateID: candidateID,
            kind: ReviewActionKind(rawValue: kind) ?? .addUserNote,
            note: note,
            correctedPrice: LearningCodec.optionalDecimal(from: correctedPrice),
            supersededBy: supersededBy
        )
    }
}

extension LearningDatabase {
    func insert(_ s: EstimateSession, _ db: Database) throws { try SessionRecord(s).insert(db) }
    func insert(_ c: EstimateSessionComponent, _ db: Database) throws { try ComponentRecord(c).insert(db) }
    func insert(_ a: EstimateAdjustment, _ db: Database) throws { try AdjustmentRecord(a).insert(db) }
    func insert(_ t: EstimateAdjustmentComponentTarget, _ db: Database) throws { try AdjustmentTargetRecord(t).insert(db) }
    func insert(_ c: CalibrationFactorCandidate, _ db: Database) throws { try CandidateRecord(c).insert(db) }
    func insert(_ f: ActiveCalibrationFactor, _ db: Database) throws { try FactorRecord(f).insert(db) }
    func insert(_ e: LearningAuditLogEntry, _ db: Database) throws { try LearningAuditRecord(e).insert(db) }
    func insert(_ r: ReviewAction, _ db: Database) throws { try ReviewActionRecord(r).insert(db) }

    func sessions(_ db: Database) throws -> [EstimateSession] {
        try SessionRecord.order(sql: "pk").fetchAll(db).map(\.domain)
    }
    func sessionComponents(_ db: Database) throws -> [EstimateSessionComponent] {
        try ComponentRecord.order(sql: "pk").fetchAll(db).map(\.domain)
    }
    func adjustments(_ db: Database) throws -> [EstimateAdjustment] {
        try AdjustmentRecord.order(sql: "pk").fetchAll(db).map(\.domain)
    }
    func candidates(_ db: Database) throws -> [CalibrationFactorCandidate] {
        try CandidateRecord.order(sql: "pk").fetchAll(db).map(\.domain)
    }
    func factors(_ db: Database) throws -> [ActiveCalibrationFactor] {
        try FactorRecord.order(sql: "pk").fetchAll(db).map(\.domain)
    }
    func auditEntries(_ db: Database) throws -> [LearningAuditLogEntry] {
        try LearningAuditRecord.order(sql: "pk").fetchAll(db).map(\.domain)
    }
    func reviewActions(_ db: Database) throws -> [ReviewAction] {
        try ReviewActionRecord.order(sql: "pk").fetchAll(db).map(\.domain)
    }

    func sessions() throws -> [EstimateSession] { try read { try sessions($0) } }
    func sessionComponents() throws -> [EstimateSessionComponent] { try read { try sessionComponents($0) } }
    func adjustments() throws -> [EstimateAdjustment] { try read { try adjustments($0) } }
    func candidates() throws -> [CalibrationFactorCandidate] { try read { try candidates($0) } }
    func factors() throws -> [ActiveCalibrationFactor] { try read { try factors($0) } }
    func auditEntries() throws -> [LearningAuditLogEntry] { try read { try auditEntries($0) } }
    func reviewActions() throws -> [ReviewAction] { try read { try reviewActions($0) } }

    func rowCount(table: String) throws -> Int {
        try read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0 }
    }
}

struct KorpusSessionSnapshotRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "korpus_session_snapshots"
    var pk: Int64?
    var recordID: String
    var sessionID: String
    var snapshotJSON: String
    var createdAt: String

    init(sessionID: String, snapshot: [String: Double], createdAt: Date = Date()) {
        pk = nil
        recordID = UUID().uuidString
        self.sessionID = sessionID
        snapshotJSON = LearningCodec.jsonDoubleMap(from: snapshot)
        self.createdAt = LearningCodec.string(from: createdAt)
    }

    var domainSnapshot: [String: Double] { LearningCodec.doubleMap(from: snapshotJSON) }
}

struct KorpusAdjustmentRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case pk, recordID, sessionID, createdAt, key = "schluessel", modellWert, beobachteterWert, reason, note, status }

    static let databaseTableName = "korpus_adjustments"
    var pk: Int64?
    var recordID: String
    var sessionID: String
    var createdAt: String
    var key: String
    var modellWert: Double
    var beobachteterWert: Double
    var reason: String
    var note: String
    var status: String

    init(_ a: KorpusAdjustment) {
        pk = nil
        recordID = a.id
        sessionID = a.sessionID
        createdAt = LearningCodec.string(from: a.createdAt)
        key = a.ziel.schaetzmodellSchluessel
        modellWert = a.modellWert
        beobachteterWert = a.beobachteterWert
        reason = a.reason.rawValue
        note = a.note
        status = a.status.rawValue
    }

    var domain: KorpusAdjustment? {
        guard let ziel = KorpusKalibrierZiel.von(schluessel: key) else { return nil }
        return KorpusAdjustment(
            id: recordID, sessionID: sessionID, createdAt: LearningCodec.date(from: createdAt),
            ziel: ziel, modellWert: modellWert, beobachteterWert: beobachteterWert,
            reason: EstimateAdjustmentReason(rawValue: reason) ?? .materialUnderestimated,
            note: note, status: LearningRecordStatus(rawValue: status) ?? .active)
    }
}

struct KorpusCandidateRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case pk, recordID, createdAt, key = "schluessel", sampleCount, weightedPercentDelta, aktuellerWert, vorgeschlagenerWert, adjustmentIDs, status, note }

    static let databaseTableName = "korpus_calibration_candidates"
    var pk: Int64?
    var recordID: String
    var createdAt: String
    var key: String
    var sampleCount: Int
    var weightedPercentDelta: Double
    var aktuellerWert: Double
    var vorgeschlagenerWert: Double
    var adjustmentIDs: String
    var status: String
    var note: String

    init(_ c: KorpusCalibrationCandidate) {
        pk = nil
        recordID = c.id
        createdAt = LearningCodec.string(from: c.createdAt)
        key = c.ziel.schaetzmodellSchluessel
        sampleCount = c.sampleCount
        weightedPercentDelta = c.weightedPercentDelta
        aktuellerWert = c.aktuellerWert
        vorgeschlagenerWert = c.vorgeschlagenerWert
        adjustmentIDs = LearningCodec.json(from: c.adjustmentIDs)
        status = c.status.rawValue
        note = c.note
    }

    var domain: KorpusCalibrationCandidate? {
        guard let ziel = KorpusKalibrierZiel.von(schluessel: key) else { return nil }
        return KorpusCalibrationCandidate(
            id: recordID, createdAt: LearningCodec.date(from: createdAt), ziel: ziel,
            sampleCount: sampleCount, weightedPercentDelta: weightedPercentDelta,
            aktuellerWert: aktuellerWert, vorgeschlagenerWert: vorgeschlagenerWert,
            adjustmentIDs: LearningCodec.stringArray(from: adjustmentIDs),
            status: LearningRecordStatus(rawValue: status) ?? .candidate, note: note)
    }
}

struct KorpusPromotionRecord: Codable, FetchableRecord, PersistableRecord {
    enum CodingKeys: String, CodingKey { case pk, recordID, candidateID, createdAt, key = "schluessel", alterWert, neuerWert, sampleCount, airtableGeschrieben, airtableFehler }

    static let databaseTableName = "korpus_kalibrier_promotions"
    var pk: Int64?
    var recordID: String
    var candidateID: String
    var createdAt: String
    var key: String
    var alterWert: Double
    var neuerWert: Double
    var sampleCount: Int
    var airtableGeschrieben: Bool
    var airtableFehler: String?

    init(_ p: KorpusKalibrierPromotion) {
        pk = nil
        recordID = p.id
        candidateID = p.candidateID
        createdAt = LearningCodec.string(from: p.createdAt)
        key = p.ziel.schaetzmodellSchluessel
        alterWert = p.alterWert
        neuerWert = p.neuerWert
        sampleCount = p.sampleCount
        airtableGeschrieben = p.airtableGeschrieben
        airtableFehler = p.airtableFehler
    }

    var domain: KorpusKalibrierPromotion? {
        guard let ziel = KorpusKalibrierZiel.von(schluessel: key) else { return nil }
        return KorpusKalibrierPromotion(
            id: recordID, candidateID: candidateID, createdAt: LearningCodec.date(from: createdAt),
            ziel: ziel, alterWert: alterWert, neuerWert: neuerWert, sampleCount: sampleCount,
            airtableGeschrieben: airtableGeschrieben, airtableFehler: airtableFehler)
    }
}

extension LearningDatabase {
    func saveKorpusSnapshot(sessionID: String, snapshot: [String: Double], _ db: Database) throws {
        try KorpusSessionSnapshotRecord(sessionID: sessionID, snapshot: snapshot).insert(db)
    }
    func korpusSnapshot(sessionID: String, _ db: Database) throws -> [String: Double]? {
        try KorpusSessionSnapshotRecord.filter(Column("sessionID") == sessionID).fetchOne(db)?.domainSnapshot
    }

    func insert(_ a: KorpusAdjustment, _ db: Database) throws { try KorpusAdjustmentRecord(a).insert(db) }
    func insert(_ c: KorpusCalibrationCandidate, _ db: Database) throws { try KorpusCandidateRecord(c).insert(db) }
    func insert(_ p: KorpusKalibrierPromotion, _ db: Database) throws { try KorpusPromotionRecord(p).insert(db) }

    func korpusAdjustments(_ db: Database) throws -> [KorpusAdjustment] {
        try KorpusAdjustmentRecord.order(sql: "pk").fetchAll(db).compactMap(\.domain)
    }
    func korpusCandidates(_ db: Database) throws -> [KorpusCalibrationCandidate] {
        try KorpusCandidateRecord.order(sql: "pk").fetchAll(db).compactMap(\.domain)
    }
    func korpusPromotions(_ db: Database) throws -> [KorpusKalibrierPromotion] {
        try KorpusPromotionRecord.order(sql: "pk").fetchAll(db).compactMap(\.domain)
    }

    func korpusAdjustments() throws -> [KorpusAdjustment] { try read { try korpusAdjustments($0) } }
    func korpusCandidates() throws -> [KorpusCalibrationCandidate] { try read { try korpusCandidates($0) } }
    func korpusPromotions() throws -> [KorpusKalibrierPromotion] { try read { try korpusPromotions($0) } }
}

struct AirtableOfferSyncRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "airtable_offer_sync"
    var pk: Int64?
    var recordID: String
    var airtableRecordID: String
    var offerKind: String
    var nettoEur: String
    var offerStatus: String
    var partner: String
    var docSHA256: String?
    var importedAt: String
    var reviewActionID: String?
    var syncStatus: String
    var offerDate: String?

    init(_ e: AirtableOfferSyncEntry) {
        pk = nil
        recordID = e.id
        airtableRecordID = e.airtableRecordID
        offerKind = e.offerKind.rawValue
        nettoEur = LearningCodec.decimalString(from: e.nettoEur)
        offerStatus = e.offerStatus.rawValue
        partner = e.partner
        docSHA256 = e.docSHA256
        importedAt = LearningCodec.string(from: e.importedAt)
        reviewActionID = e.reviewActionID
        syncStatus = e.syncStatus
        offerDate = e.offerDate
    }

    var domain: AirtableOfferSyncEntry {
        AirtableOfferSyncEntry(
            id: recordID,
            airtableRecordID: airtableRecordID,
            offerKind: AirtableOfferKind(rawValue: offerKind) ?? .eingehend,
            nettoEur: LearningCodec.decimal(from: nettoEur),
            offerStatus: AirtableOfferStatus(rawValue: offerStatus) ?? .offen,
            partner: partner,
            docSHA256: docSHA256,
            importedAt: LearningCodec.date(from: importedAt),
            reviewActionID: reviewActionID,
            syncStatus: syncStatus,
            offerDate: offerDate
        )
    }
}

extension LearningDatabase {
    func insert(_ e: AirtableOfferSyncEntry, _ db: Database) throws {
        try AirtableOfferSyncRecord(e).insert(db)
    }

    func airtableOfferSyncEntries(_ db: Database) throws -> [AirtableOfferSyncEntry] {
        try AirtableOfferSyncRecord.order(sql: "pk").fetchAll(db).map(\.domain)
    }

    func airtableOfferSyncEntries() throws -> [AirtableOfferSyncEntry] {
        try read { try airtableOfferSyncEntries($0) }
    }

    func airtableRecordIDExists(_ airtableRecordID: String) throws -> Bool {
        try read { db in
            (try Int.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM airtable_offer_sync WHERE airtableRecordID = ?)",
                arguments: [airtableRecordID]
            ) ?? 0) == 1
        }
    }
}

extension LearningDatabase {
    @discardableResult
    public func importJSONLSnapshot(from directory: URL) throws -> Int {
        var total = 0
        total += try importJSONLFile(directory, "estimate_sessions", EstimateSession.self) { try self.insert($0, $1) }
        total += try importJSONLFile(directory, "estimate_session_components", EstimateSessionComponent.self) { try self.insert($0, $1) }
        total += try importJSONLFile(directory, "estimate_adjustments", EstimateAdjustment.self) { try self.insert($0, $1) }
        total += try importJSONLFile(directory, "estimate_adjustment_component_targets", EstimateAdjustmentComponentTarget.self) { try self.insert($0, $1) }
        total += try importJSONLFile(directory, "calibration_factor_candidates", CalibrationFactorCandidate.self) { try self.insert($0, $1) }
        total += try importJSONLFile(directory, "active_calibration_factors", ActiveCalibrationFactor.self) { try self.insert($0, $1) }
        total += try importJSONLFile(directory, "learning_audit_log", LearningAuditLogEntry.self) { try self.insert($0, $1) }
        return total
    }

    private func importJSONLFile<T: Decodable>(
        _ directory: URL,
        _ fileName: String,
        _ type: T.Type,
        insert: @escaping (T, Database) throws -> Void
    ) throws -> Int {
        let url = directory.appendingPathComponent("\(fileName).jsonl")
        guard FileManager.default.fileExists(atPath: url.path) else { return 0 }
        let content = try Data(contentsOf: url)
        let digest = SHA256.hash(data: content).map { String(format: "%02x", $0) }.joined()
        let fingerprint = "\(fileName):\(digest)"

        let already = try read { db in
            (try Int.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM learning_import_log WHERE fingerprint = ?)", arguments: [fingerprint]) ?? 0) == 1
        }
        if already { return 0 }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let lines = String(decoding: content, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: true)

        return try write { db in
            var count = 0
            for line in lines {
                let value = try decoder.decode(T.self, from: Data(line.utf8))
                try insert(value, db)
                count += 1
            }
            try db.execute(
                sql: "INSERT INTO learning_import_log(sourceFile, fingerprint, recordCount, importedAt) VALUES (?, ?, ?, ?)",
                arguments: [fileName, fingerprint, count, LearningCodec.string(from: Date())]
            )
            return count
        }
    }
}
