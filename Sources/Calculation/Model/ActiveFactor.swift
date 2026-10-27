import Foundation

struct ActiveFactor: Equatable, Identifiable, Sendable {
    let id: String
    let candidateID: String
    let createdAt: Date
    let reason: AdjustmentReason
    let target: AdjustmentTarget
    let multiplier: Decimal
    let weightedPercentDelta: Double
    let sampleCount: Int
    let status: LearningStatus

    init(id: String = UUID().uuidString, candidateID: String, createdAt: Date = Date(), reason: AdjustmentReason, target: AdjustmentTarget, multiplier: Decimal, weightedPercentDelta: Double, sampleCount: Int, status: LearningStatus = .active) {
        self.id = id
        self.candidateID = candidateID
        self.createdAt = createdAt
        self.reason = reason
        self.target = target
        self.multiplier = multiplier
        self.weightedPercentDelta = weightedPercentDelta
        self.sampleCount = sampleCount
        self.status = status
    }
}
