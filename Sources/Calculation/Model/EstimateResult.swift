import Foundation

struct EstimateResult: Equatable, Sendable {
    let request: EstimateInput
    let lines: [EstimateLine]
    let baseTotalBand: PriceBand
    let totalBand: PriceBand
    let baseLaborValue: Decimal
    let laborValue: Decimal
    let calibrationApplications: [AppliedFactor]
    let confidence: Double
    let evidence: [EvidenceCase]
    let dataGaps: [Notice]
    let excludedRisks: [Notice]
    let scopeNotes: [Notice]
    let bottomUpCost: BottomUpEstimate?

    init(request: EstimateInput, lines: [EstimateLine], totalBand: PriceBand, laborValue: Decimal, confidence: Double, evidence: [EvidenceCase], dataGaps: [Notice], excludedRisks: [Notice], scopeNotes: [Notice], baseTotalBand: PriceBand? = nil, baseLaborValue: Decimal? = nil, calibrationApplications: [AppliedFactor] = [], bottomUpCost: BottomUpEstimate? = nil) {
        self.bottomUpCost = bottomUpCost
        self.request = request
        self.lines = lines
        self.baseTotalBand = baseTotalBand ?? totalBand
        self.totalBand = totalBand
        self.baseLaborValue = baseLaborValue ?? laborValue
        self.laborValue = laborValue
        self.calibrationApplications = calibrationApplications
        self.confidence = confidence
        self.evidence = evidence
        self.dataGaps = dataGaps
        self.excludedRisks = excludedRisks
        self.scopeNotes = scopeNotes
    }
}

struct EstimateLine: Equatable, Identifiable, Sendable {
    let id: UUID
    let component: EstimateComponent
    let priceBand: PriceBand
    let evidence: [EvidenceCase]
    let rationale: Notice
}

struct AppliedFactor: Equatable, Identifiable, Sendable {
    let id: String
    let factorID: String
    let reason: AdjustmentReason
    let target: AdjustmentTarget
    let multiplier: Decimal
    let appliedDeltaNet: Decimal

    init(id: String = UUID().uuidString, factorID: String, reason: AdjustmentReason, target: AdjustmentTarget, multiplier: Decimal, appliedDeltaNet: Decimal) {
        self.id = id
        self.factorID = factorID
        self.reason = reason
        self.target = target
        self.multiplier = multiplier
        self.appliedDeltaNet = appliedDeltaNet
    }
}

struct BottomUpEstimate: Equatable, Sendable {
    let laborNet: Decimal
    let materialNet: Decimal
    let total: Decimal
    let carcassEquivalents: Double
    let frontAreaM2: Double
    let stageBreakdown: [StageCost]
    let assumptions: [Notice]
}

struct StageCost: Equatable, Sendable {
    let stage: String
    let minutesPerCarcass: Double
    let ratePerHour: Decimal
    let cost: Decimal
}

struct EvidenceCase: Equatable, Identifiable, Sendable {
    var id: String { priceAnchorID }
    let priceAnchorID: String
    let sourceFile: String
    let page: Int
    let supplier: String
    let project: String
    let component: String
    let scope: String
    let confidence: Double
    let netPrice: Decimal
    let unitPrice: Decimal?
    let quote: String
    let risksExcluded: [Notice]
}
