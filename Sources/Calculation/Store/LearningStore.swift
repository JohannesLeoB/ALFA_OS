import Foundation
import GRDB
import Storage

public final class LearningStore: FactorPort {
    static let outlierPercent = 25.0
    static let carcassOutlierPercent = 50.0
    static let minimumSamples = 3
    static let strongSamples = 5

    let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    func saveSession(from result: EstimateResult) throws -> EstimateSession {
        let session = EstimateSession(
            requestText: result.request.rawText,
            baseLowNet: result.baseTotalBand.low,
            baseMidNet: result.baseTotalBand.expected,
            baseHighNet: result.baseTotalBand.high,
            laborValueNet: result.baseLaborValue,
            evidenceIDs: result.evidence.map(\.priceAnchorID)
        )
        let components: [SessionComponent] = result.lines.enumerated().map { index, line in
            SessionComponent(
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
        try database.write { db in
            try StoredSession(session).insert(db)
            for component in components { try StoredComponent(component).insert(db) }
            try Self.audit(db, entityID: session.id, table: "estimate_sessions", action: "created")
        }
        return session
    }

    func appendAdjustment(sessionID: String, percentDelta: Double, euroDelta: Decimal?, reason: AdjustmentReason, target: AdjustmentTarget, learn: Bool, note: String) throws -> EstimateAdjustment {
        try database.write { db in
            guard let session = try Self.sessions(db).last(where: { $0.id == sessionID }) else {
                throw LearningFailure.sessionNotFound(sessionID)
            }
            let basis = try Self.baseMidNet(db, session: session, target: target)
            let adjustedMid = euroDelta.map { basis + $0 } ?? (basis * Decimal(1 + percentDelta / 100))
            let inferredPercent = (basis == 0 ? Decimal(percentDelta) : ((adjustedMid - basis) / basis * Decimal(100))).double
            let status: LearningStatus = abs(inferredPercent) > Self.outlierPercent ? .reviewOutlier : .active
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
            try StoredAdjustment(adjustment).insert(db)

            let matchingComponents = try Self.sessionComponents(db)
                .filter { $0.sessionID == sessionID && (target == .wholeEstimate || $0.adjustmentTarget == target) }
            if matchingComponents.isEmpty {
                try StoredAdjustmentTarget(ComponentAdjustmentTarget(adjustmentID: adjustment.id, sessionComponentID: nil, target: target, percentDelta: inferredPercent, status: status)).insert(db)
            } else {
                for component in matchingComponents {
                    try StoredAdjustmentTarget(ComponentAdjustmentTarget(adjustmentID: adjustment.id, sessionComponentID: component.id, target: target, percentDelta: inferredPercent, status: status)).insert(db)
                }
            }
            try Self.audit(db, entityID: adjustment.id, table: "estimate_adjustments", action: learn ? "learning_saved" : "estimate_adjusted", detail: status.rawValue)
            if learn {
                try Self.regenerateCandidate(db, reason: reason, target: target)
            }
            return adjustment
        }
    }

    func promoteCalibration(candidateID: String) throws -> ActiveFactor {
        try database.write { db in
            guard let candidate = try Self.latestByID(Self.candidates(db)).last(where: { $0.id == candidateID }) else {
                throw LearningFailure.candidateNotFound(candidateID)
            }
            let factor = ActiveFactor(
                candidateID: candidate.id,
                reason: candidate.reason,
                target: candidate.target,
                multiplier: candidate.multiplier,
                weightedPercentDelta: candidate.weightedPercentDelta,
                sampleCount: candidate.sampleCount
            )
            try StoredFactor(factor).insert(db)
            let promoted = FactorCandidate(
                id: candidate.id,
                createdAt: Date(),
                reason: candidate.reason,
                target: candidate.target,
                sampleCount: candidate.sampleCount,
                weightedPercentDelta: candidate.weightedPercentDelta,
                multiplier: candidate.multiplier,
                adjustmentIDs: candidate.adjustmentIDs,
                status: .promoted,
                note: Notice("calc.note.promoted", [factor.id])
            )
            try StoredCandidate(promoted).insert(db)
            try Self.audit(db, entityID: factor.id, table: "active_calibration_factors", action: "promoted", detail: candidate.id)
            return factor
        }
    }

    func saveCarcassSnapshot(sessionID: String, snapshot: [String: Double]) throws {
        try database.write { db in
            try StoredCarcassSnapshot(sessionID: sessionID, snapshot: snapshot).insert(db)
        }
    }

    func appendCarcassAdjustment(sessionID: String, target: CarcassCalibrationTarget, observedValue: Double, reason: AdjustmentReason, note: String, learn: Bool) throws -> CarcassAdjustment {
        try database.write { db in
            guard let snapshot = try StoredCarcassSnapshot.filter(Column("sessionID") == sessionID).fetchOne(db)?.snapshot else {
                throw LearningFailure.carcassSnapshotMissing(sessionID)
            }
            guard let modelValue = snapshot[target.key] else {
                throw LearningFailure.carcassTargetNotInSession(key: target.key, sessionID: sessionID)
            }
            let provisional = CarcassAdjustment(
                sessionID: sessionID, target: target, modelValue: modelValue,
                observedValue: observedValue, reason: reason, note: note)
            let status: LearningStatus = abs(provisional.percentDelta) > Self.carcassOutlierPercent ? .reviewOutlier : .active
            let adjustment = CarcassAdjustment(
                id: provisional.id, sessionID: sessionID, createdAt: provisional.createdAt, target: target,
                modelValue: modelValue, observedValue: observedValue, reason: reason, note: note, status: status)
            try StoredCarcassAdjustment(adjustment).insert(db)
            try Self.audit(db, entityID: adjustment.id, table: "carcass_adjustments", action: learn ? "learning_saved" : "estimate_adjusted", detail: target.key)
            if learn {
                try Self.regenerateCarcassCandidate(db, target: target)
            }
            return adjustment
        }
    }

    func summary() throws -> LearningSummary {
        try database.read { db in
            let adjustments = try Self.adjustments(db)
            return LearningSummary(
                sessions: try StoredSession.fetchCount(db),
                adjustments: adjustments.count,
                candidates: Self.latestByID(try Self.candidates(db)),
                activeFactors: Self.latestByID(try Self.factors(db)).filter { $0.status == .active },
                outliers: adjustments.filter { $0.status == .reviewOutlier }.count
            )
        }
    }

    func activeFactors() throws -> [ActiveFactor] {
        try database.read { db in
            Self.latestByID(try Self.factors(db)).filter { $0.status == .active }
        }
    }

    private static func regenerateCandidate(_ db: Database, reason: AdjustmentReason, target: AdjustmentTarget) throws {
        let similar = try adjustments(db)
            .filter { $0.reason == reason && $0.target == target && $0.status == .active && abs($0.percentDelta) <= outlierPercent }
        guard similar.count >= minimumSamples else { return }
        let weighted = weightedPercent(similar.map { (percent: $0.percentDelta, weight: $0.reason.weight) })
        let status = candidateStatus(sampleCount: similar.count)
        let candidate = FactorCandidate(
            id: "CAL-\(reason.rawValue)-\(target.rawValue)",
            reason: reason,
            target: target,
            sampleCount: similar.count,
            weightedPercentDelta: weighted,
            multiplier: Decimal(1 + weighted / 100),
            adjustmentIDs: similar.map(\.id),
            status: status,
            note: Notice("calc.note.candidate", [String(similar.count)])
        )
        try StoredCandidate(candidate).insert(db)
        try audit(db, entityID: candidate.id, table: "calibration_factor_candidates", action: status.rawValue, detail: String(similar.count))
    }

    private static func regenerateCarcassCandidate(_ db: Database, target: CarcassCalibrationTarget) throws {
        let similar = try carcassAdjustments(db)
            .filter { $0.target == target && $0.status == .active && abs($0.percentDelta) <= carcassOutlierPercent }
        guard similar.count >= minimumSamples else { return }
        let weighted = weightedPercent(similar.map { (percent: $0.percentDelta, weight: $0.reason.weight) })
        let status = candidateStatus(sampleCount: similar.count)
        let currentValue = similar.last?.modelValue ?? 0
        let candidate = CarcassCalibrationCandidate(
            id: "CARCASS-CAL-\(target.key)", target: target, sampleCount: similar.count,
            weightedPercentDelta: weighted, currentValue: currentValue,
            proposedValue: currentValue * (1 + weighted / 100),
            adjustmentIDs: similar.map(\.id), status: status,
            note: Notice("calc.note.carcassCandidate", [String(similar.count), target.key]))
        try StoredCarcassCandidate(candidate).insert(db)
        try audit(db, entityID: candidate.id, table: "carcass_calibration_candidates", action: status.rawValue, detail: String(similar.count))
    }

    private static func weightedPercent(_ samples: [(percent: Double, weight: Double)]) -> Double {
        let weightSum = samples.map(\.weight).reduce(0, +)
        return samples.map { $0.percent * $0.weight }.reduce(0, +) / max(weightSum, 0.01)
    }

    private static func candidateStatus(sampleCount: Int) -> LearningStatus {
        sampleCount >= strongSamples ? .strongCandidate : .candidate
    }

    private static func baseMidNet(_ db: Database, session: EstimateSession, target: AdjustmentTarget) throws -> Decimal {
        if target == .wholeEstimate { return session.baseMidNet }
        let components = try sessionComponents(db).filter { $0.sessionID == session.id && $0.adjustmentTarget == target }
        let sum = components.map(\.baseMidNet).reduce(Decimal(0), +)
        return sum > 0 ? sum : session.baseMidNet
    }

    static func latestByID<T: Identifiable>(_ records: [T]) -> [T] where T.ID == String {
        var order: [String] = []
        var latest: [String: T] = [:]
        for record in records {
            if latest[record.id] == nil { order.append(record.id) }
            latest[record.id] = record
        }
        return order.compactMap { latest[$0] }
    }

    private static func target(for component: EstimateComponent) -> AdjustmentTarget {
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

enum LearningFailure: Error, Equatable, Sendable {
    case sessionNotFound(String)
    case candidateNotFound(String)
    case carcassSnapshotMissing(String)
    case carcassTargetNotInSession(key: String, sessionID: String)
    case unknownCarcassTarget(String)
}

struct LearningSummary: Equatable, Sendable {
    let sessions: Int
    let adjustments: Int
    let candidates: [FactorCandidate]
    let activeFactors: [ActiveFactor]
    let outliers: Int
}
