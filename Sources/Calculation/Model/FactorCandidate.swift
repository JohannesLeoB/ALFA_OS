import Foundation

struct FactorCandidate: Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let reason: AdjustmentReason
    let target: AdjustmentTarget
    let sampleCount: Int
    let weightedPercentDelta: Double
    let multiplier: Decimal
    let adjustmentIDs: [String]
    let status: LearningStatus
    let note: Notice

    init(id: String = UUID().uuidString, createdAt: Date = Date(), reason: AdjustmentReason, target: AdjustmentTarget, sampleCount: Int, weightedPercentDelta: Double, multiplier: Decimal, adjustmentIDs: [String], status: LearningStatus, note: Notice) {
        self.id = id
        self.createdAt = createdAt
        self.reason = reason
        self.target = target
        self.sampleCount = sampleCount
        self.weightedPercentDelta = weightedPercentDelta
        self.multiplier = multiplier
        self.adjustmentIDs = adjustmentIDs
        self.status = status
        self.note = note
    }
}
