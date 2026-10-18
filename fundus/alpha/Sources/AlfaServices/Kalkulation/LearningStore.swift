import Foundation
import AlfaKit
import GRDB
import MykilosKalkulationsCore

public enum LearningStoreError: Error, CustomStringConvertible {
    case sessionNotFound(String)
    case candidateNotFound(String)
    case factorNotFound(String)
    case korpusSnapshotFehlt(String)
    case korpusZielNichtInSession(key: String, sessionID: String)
    case korpusCandidateNotFound(String)

    public var description: String {
        switch self {
        case .sessionNotFound(let id): "Estimate session nicht gefunden: \(id)"
        case .candidateNotFound(let id): "CalibrationFactorCandidate nicht gefunden: \(id)"
        case .factorNotFound(let id): "ActiveCalibrationFactor nicht gefunden: \(id)"
        case .korpusSnapshotFehlt(let id): "Kein Korpus-Parameter-Snapshot für Session \(id) — keine Korpus-Schätzung oder zu alt."
        case .korpusZielNichtInSession(let key, let id): "Ziel „\(key)“ war in Session \(id) nicht wirksam (z. B. andere Front-Ausführung) — keine Korrektur möglich."
        case .korpusCandidateNotFound(let id): "KorpusCalibrationCandidate nicht gefunden: \(id)"
        }
    }
}

public struct LearningSummary: Equatable {
    public let sessions: Int
    public let adjustments: Int
    public let candidates: [CalibrationFactorCandidate]
    public let activeFactors: [ActiveCalibrationFactor]
    public let outliers: Int
}

public final class LearningStore: CalibrationFactorProviding, @unchecked Sendable {
    public let directory: URL
    private var cachedDatabase: LearningDatabase?

    private let dbLock = NSLock()

    public init(directory: URL = LearningStore.defaultDirectory()) {
        self.directory = directory
    }

    public static func defaultDirectory() -> URL {
        if let override = ProcessInfo.processInfo.environment["MYKILOS_LEARNING_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent("\(AppKennung.name)/Kalkulationslabor/Learning", isDirectory: true)
    }

    public func database() throws -> LearningDatabase {
        dbLock.lock()
        defer { dbLock.unlock() }
        if let cachedDatabase { return cachedDatabase }
        let db = try LearningDatabase(url: directory.appendingPathComponent("learning.sqlite"))
        _ = try db.importJSONLSnapshot(from: directory)
        cachedDatabase = db
        return db
    }

    public func saveSession(from result: EstimateResult) throws -> EstimateSession {
        let db = try database()
        let session = EstimateSession(
            requestText: result.request.rawText,
            baseLowNet: result.baseTotalBand.low,
            baseMidNet: result.baseTotalBand.expected,
            baseHighNet: result.baseTotalBand.high,
            laborValueNet: result.baseLaborValue,
            evidenceIDs: result.evidence.map(\.priceAnchorID)
        )
        let components: [EstimateSessionComponent] = result.lines.enumerated().map { index, line in
            EstimateSessionComponent(
                sessionID: session.id,
                componentIndex: index,
                componentClass: line.component.componentClass,
                componentType: line.component.type,
                adjustmentTarget: Self.target(for: line.component),
                baseLowNet: line.priceBand.low,
                baseMidNet: line.priceBand.expected,
                baseHighNet: line.priceBand.high,
                evidenceIDs: line.evidence.map(\.priceAnchorID)
            )
        }

        try db.write { conn in
            try db.insert(session, conn)
            for component in components { try db.insert(component, conn) }
            try db.insert(LearningAuditLogEntry(entityID: session.id, entityTable: "estimate_sessions", action: "created", message: "Estimate session captured append-only."), conn)
        }
        return session
    }

    public func appendAdjustment(sessionID: String, percentDelta: Double, euroDelta: Decimal?, reason: EstimateAdjustmentReason, target: EstimateAdjustmentTarget, learn: Bool, note: String = "") throws -> EstimateAdjustment {
        let db = try database()
        return try db.write { conn in
            guard let session = try db.sessions(conn).last(where: { $0.id == sessionID }) else {
                throw LearningStoreError.sessionNotFound(sessionID)
            }
            let basis = try Self.baseMidNet(db, conn, session: session, target: target)
            let adjustedMid = euroDelta.map { basis + $0 } ?? (basis * Decimal(1 + percentDelta / 100))
            let inferredPercent = NSDecimalNumber(decimal: basis == 0 ? Decimal(percentDelta) : ((adjustedMid - basis) / basis * Decimal(100))).doubleValue
            let status: LearningRecordStatus = abs(inferredPercent) > 25 ? .reviewOutlier : .active
            let adjustment = EstimateAdjustment(
                sessionID: sessionID,
                percentDelta: inferredPercent,
                euroDelta: euroDelta,
                adjustedMidNet: adjustedMid,
                reason: reason,
                target: target,
                status: status,
                note: note
            )
            try db.insert(adjustment, conn)

            let matchingComponents = try db.sessionComponents(conn)
                .filter { $0.sessionID == sessionID && (target == .wholeEstimate || $0.adjustmentTarget == target) }
            if matchingComponents.isEmpty {
                try db.insert(EstimateAdjustmentComponentTarget(adjustmentID: adjustment.id, sessionComponentID: nil, target: target, percentDelta: inferredPercent, status: status), conn)
            } else {
                for component in matchingComponents {
                    try db.insert(EstimateAdjustmentComponentTarget(adjustmentID: adjustment.id, sessionComponentID: component.id, target: target, percentDelta: inferredPercent, status: status), conn)
                }
            }
            try db.insert(LearningAuditLogEntry(entityID: adjustment.id, entityTable: "estimate_adjustments", action: learn ? "learning_saved" : "estimate_adjusted", message: "Adjustment stored with status \(status.rawValue)."), conn)
            if learn {
                try Self.regenerateCandidate(db, conn, reason: reason, target: target)
            }
            return adjustment
        }
    }

    public func promoteCalibration(candidateID: String) throws -> ActiveCalibrationFactor {
        let db = try database()
        return try db.write { conn in
            guard let candidate = try Self.latestByID(db.candidates(conn)).last(where: { $0.id == candidateID }) else {
                throw LearningStoreError.candidateNotFound(candidateID)
            }
            let factor = ActiveCalibrationFactor(
                candidateID: candidate.id,
                reason: candidate.reason,
                target: candidate.target,
                multiplier: candidate.multiplier,
                weightedPercentDelta: candidate.weightedPercentDelta,
                sampleCount: candidate.sampleCount
            )
            try db.insert(factor, conn)
            let promoted = CalibrationFactorCandidate(
                id: candidate.id,
                createdAt: Date(),
                reason: candidate.reason,
                target: candidate.target,
                sampleCount: candidate.sampleCount,
                weightedPercentDelta: candidate.weightedPercentDelta,
                multiplier: candidate.multiplier,
                adjustmentIDs: candidate.adjustmentIDs,
                status: .promoted,
                note: "Promoted to active factor \(factor.id)."
            )
            try db.insert(promoted, conn)
            try db.insert(LearningAuditLogEntry(entityID: factor.id, entityTable: "active_calibration_factors", action: "promoted", message: "Candidate \(candidate.id) promoted."), conn)
            return factor
        }
    }

    public func deactivateCalibration(factorID: String) throws -> ActiveCalibrationFactor {
        let db = try database()
        return try db.write { conn in
            guard let factor = try Self.latestByID(db.factors(conn)).last(where: { $0.id == factorID }) else {
                throw LearningStoreError.factorNotFound(factorID)
            }
            let inactive = ActiveCalibrationFactor(
                id: factor.id,
                candidateID: factor.candidateID,
                createdAt: Date(),
                reason: factor.reason,
                target: factor.target,
                multiplier: factor.multiplier,
                weightedPercentDelta: factor.weightedPercentDelta,
                sampleCount: factor.sampleCount,
                status: .inactive
            )
            try db.insert(inactive, conn)
            try db.insert(LearningAuditLogEntry(entityID: factor.id, entityTable: "active_calibration_factors", action: "deactivated", message: "Factor set inactive append-only."), conn)
            return inactive
        }
    }

    public func saveKorpusSnapshot(sessionID: String, snapshot: [String: Double]) throws {
        let db = try database()
        try db.write { conn in try db.saveKorpusSnapshot(sessionID: sessionID, snapshot: snapshot, conn) }
    }

    static let korpusAusreisserSchwelle = 50.0

    @discardableResult
    public func appendKorpusAdjustment(
        sessionID: String, ziel: KorpusKalibrierZiel, beobachteterWert: Double,
        reason: EstimateAdjustmentReason, note: String = "", learn: Bool
    ) throws -> KorpusAdjustment {
        let db = try database()
        return try db.write { conn in
            guard let snapshot = try db.korpusSnapshot(sessionID: sessionID, conn) else {
                throw LearningStoreError.korpusSnapshotFehlt(sessionID)
            }
            guard let modellWert = snapshot[ziel.schaetzmodellSchluessel] else {
                throw LearningStoreError.korpusZielNichtInSession(key: ziel.schaetzmodellSchluessel, sessionID: sessionID)
            }
            let vorlaeufig = KorpusAdjustment(
                sessionID: sessionID, ziel: ziel, modellWert: modellWert,
                beobachteterWert: beobachteterWert, reason: reason, note: note)
            let status: LearningRecordStatus = abs(vorlaeufig.percentDelta) > Self.korpusAusreisserSchwelle ? .reviewOutlier : .active
            let adjustment = KorpusAdjustment(
                id: vorlaeufig.id, sessionID: sessionID, createdAt: vorlaeufig.createdAt, ziel: ziel,
                modellWert: modellWert, beobachteterWert: beobachteterWert, reason: reason, note: note, status: status)
            try db.insert(adjustment, conn)
            try db.insert(LearningAuditLogEntry(
                entityID: adjustment.id, entityTable: "korpus_adjustments",
                action: learn ? "learning_saved" : "estimate_adjusted",
                message: "Korpus-Korrektur \(ziel.schaetzmodellSchluessel): \(modellWert) → \(beobachteterWert) (Status \(status.rawValue))."), conn)
            if learn {
                try Self.regenerateKorpusCandidate(db, conn, ziel: ziel)
            }
            return adjustment
        }
    }

    public func latestKorpusCandidates() throws -> [KorpusCalibrationCandidate] {
        Self.latestByID(try database().korpusCandidates())
    }

    public func korpusCandidate(id: String) throws -> KorpusCalibrationCandidate? {
        try latestKorpusCandidates().first { $0.id == id }
    }

    public func korpusAdjustments() throws -> [KorpusAdjustment] {
        try database().korpusAdjustments()
    }

    public func korpusPromotions() throws -> [KorpusKalibrierPromotion] {
        try database().korpusPromotions()
    }

    @discardableResult
    public func recordKorpusPromotion(
        candidateID: String, airtableGeschrieben: Bool, airtableFehler: String?
    ) throws -> KorpusKalibrierPromotion {
        let db = try database()
        return try db.write { conn in
            guard let candidate = try Self.latestByID(db.korpusCandidates(conn)).last(where: { $0.id == candidateID }) else {
                throw LearningStoreError.korpusCandidateNotFound(candidateID)
            }
            let promotion = KorpusKalibrierPromotion(
                candidateID: candidate.id, ziel: candidate.ziel, alterWert: candidate.aktuellerWert,
                neuerWert: candidate.vorgeschlagenerWert, sampleCount: candidate.sampleCount,
                airtableGeschrieben: airtableGeschrieben, airtableFehler: airtableFehler)
            try db.insert(promotion, conn)
            let promoted = KorpusCalibrationCandidate(
                id: candidate.id, createdAt: Date(), ziel: candidate.ziel, sampleCount: candidate.sampleCount,
                weightedPercentDelta: candidate.weightedPercentDelta, aktuellerWert: candidate.aktuellerWert,
                vorgeschlagenerWert: candidate.vorgeschlagenerWert, adjustmentIDs: candidate.adjustmentIDs,
                status: .promoted,
                note: airtableGeschrieben ? "Promoted, nach Airtable geschrieben (\(promotion.id))."
                                          : "Promoted, NICHT nach Airtable geschrieben (Ventil zu oder Fehler) — \(promotion.id).")
            try db.insert(promoted, conn)
            try db.insert(LearningAuditLogEntry(
                entityID: promotion.id, entityTable: "korpus_kalibrier_promotions",
                action: airtableGeschrieben ? "promoted_written" : "promoted_gate_closed",
                message: "Kandidat \(candidate.id) promoted (Airtable: \(airtableGeschrieben))."), conn)
            return promotion
        }
    }

    private static func regenerateKorpusCandidate(_ db: LearningDatabase, _ conn: Database, ziel: KorpusKalibrierZiel) throws {
        let similar = try db.korpusAdjustments(conn)
            .filter { $0.ziel == ziel && $0.status == .active && abs($0.percentDelta) <= Self.korpusAusreisserSchwelle }
        guard similar.count >= 3 else { return }
        let weightSum = similar.map { $0.reason.weight }.reduce(0, +)
        let weightedPercent = similar.map { $0.percentDelta * $0.reason.weight }.reduce(0, +) / max(weightSum, 0.01)
        let status: LearningRecordStatus = similar.count >= 5 ? .strongCandidate : .candidate
        let aktuellerWert = similar.last?.modellWert ?? 0
        let vorgeschlagenerWert = aktuellerWert * (1 + weightedPercent / 100)
        let id = "KORPUS-CAL-\(ziel.schaetzmodellSchluessel)"
        let candidate = KorpusCalibrationCandidate(
            id: id, ziel: ziel, sampleCount: similar.count, weightedPercentDelta: weightedPercent,
            aktuellerWert: aktuellerWert, vorgeschlagenerWert: vorgeschlagenerWert,
            adjustmentIDs: similar.map(\.id), status: status,
            note: "\(similar.count) Korrekturen für \(ziel.schaetzmodellSchluessel), gewichtet nach Grund-Verlässlichkeit.")
        try db.insert(candidate, conn)
        try db.insert(LearningAuditLogEntry(
            entityID: candidate.id, entityTable: "korpus_calibration_candidates", action: status.rawValue,
            message: "Kandidat regeneriert aus \(similar.count) Korrekturen."), conn)
    }

    public func summary() throws -> LearningSummary {
        let adjustments = try estimateAdjustments()
        return LearningSummary(
            sessions: try estimateSessions().count,
            adjustments: adjustments.count,
            candidates: try latestCandidates(),
            activeFactors: try activeCalibrationFactors(),
            outliers: adjustments.filter { $0.status == .reviewOutlier }.count
        )
    }

    public func activeCalibrationFactors() throws -> [ActiveCalibrationFactor] {
        Self.latestByID(try database().factors())
            .filter { $0.status == .active }
    }

    public func estimateSessions() throws -> [EstimateSession] {
        try database().sessions()
    }

    public func estimateSessionComponents() throws -> [EstimateSessionComponent] {
        try database().sessionComponents()
    }

    public func estimateAdjustments() throws -> [EstimateAdjustment] {
        try database().adjustments()
    }

    public func latestCandidates() throws -> [CalibrationFactorCandidate] {
        Self.latestByID(try database().candidates())
    }

    private static func regenerateCandidate(_ db: LearningDatabase, _ conn: Database, reason: EstimateAdjustmentReason, target: EstimateAdjustmentTarget) throws {
        let similar = try db.adjustments(conn)
            .filter { $0.reason == reason && $0.target == target && $0.status == .active && abs($0.percentDelta) <= 25 }
        guard similar.count >= 3 else { return }
        let weightSum = similar.map { $0.reason.weight }.reduce(0, +)
        let weightedPercent = similar.map { $0.percentDelta * $0.reason.weight }.reduce(0, +) / max(weightSum, 0.01)
        let status: LearningRecordStatus = similar.count >= 5 ? .strongCandidate : .candidate
        let id = "CAL-\(reason.rawValue)-\(target.rawValue)"
        let multiplier = Decimal(1 + weightedPercent / 100)
        let candidate = CalibrationFactorCandidate(
            id: id,
            reason: reason,
            target: target,
            sampleCount: similar.count,
            weightedPercentDelta: weightedPercent,
            multiplier: multiplier,
            adjustmentIDs: similar.map(\.id),
            status: status,
            note: "\(similar.count) ähnliche Adjustments, weighted by reason reliability."
        )
        try db.insert(candidate, conn)
        try db.insert(LearningAuditLogEntry(entityID: candidate.id, entityTable: "calibration_factor_candidates", action: status.rawValue, message: "Candidate regenerated from \(similar.count) adjustments."), conn)
    }

    private static func baseMidNet(_ db: LearningDatabase, _ conn: Database, session: EstimateSession, target: EstimateAdjustmentTarget) throws -> Decimal {
        if target == .wholeEstimate { return session.baseMidNet }
        let components = try db.sessionComponents(conn).filter { $0.sessionID == session.id && $0.adjustmentTarget == target }
        let sum = components.map(\.baseMidNet).reduce(Decimal(0), +)
        return sum > 0 ? sum : session.baseMidNet
    }

    private static func latestByID<T: Identifiable>(_ records: [T]) -> [T] where T.ID == String {
        var order: [String] = []
        var latest: [String: T] = [:]
        for record in records {
            if latest[record.id] == nil { order.append(record.id) }
            latest[record.id] = record
        }
        return order.compactMap { latest[$0] }
    }

    private static func target(for component: EstimateComponent) -> EstimateAdjustmentTarget {
        if component.type == .drawerAddon || component.drawerCount > 0 { return .drawers }
        switch component.componentClass {
        case .kitchenRun: return .kitchenRun
        case .island: return .island
        case .tallCabinetBlock: return .tallCabinetBlock
        case .worktopSurface: return .worktop
        case .logistics: return .logistics
        default: return .wholeEstimate
        }
    }
}
