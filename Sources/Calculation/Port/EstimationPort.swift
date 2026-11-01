import Foundation

public protocol EstimationPort: AnyObject, Sendable {
    func estimate(projectID: String?, text: String, override: EstimateOverride) async throws -> CostEstimate
}

public protocol AnchorRowsPort: Sendable {
    func fetchAnchorRows() async throws -> [[String: String]]
}

public protocol ArticlePricePort: Sendable {
    func purchaseNet(matching term: String) async -> Double?
}

public protocol CarcassParameterPort: Sendable {
    func parameters() async -> CarcassParameters?
}

protocol LearningLedgerPort: FactorPort {
    func saveSession(from result: EstimateResult) throws -> EstimateSession
    func appendAdjustment(sessionID: String, percentDelta: Double, euroDelta: Decimal?, reason: AdjustmentReason, target: AdjustmentTarget, learn: Bool, note: String) throws -> EstimateAdjustment
    func promoteCalibration(candidateID: String) throws -> ActiveFactor
    func saveCarcassSnapshot(sessionID: String, snapshot: [String: Double]) throws
    func appendCarcassAdjustment(sessionID: String, target: CarcassCalibrationTarget, observedValue: Double, reason: AdjustmentReason, note: String, learn: Bool) throws -> CarcassAdjustment
    func summary() throws -> LearningSummary
}

protocol FactorPort: Sendable {
    func activeFactors() throws -> [ActiveFactor]
}

public protocol PriceAnchorPort: Sendable {
    func activeAnchors() throws -> [CandidateReleaseDecision]
}
