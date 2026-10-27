import Foundation

struct EstimateAdjustment: Equatable, Identifiable, Sendable {
    let id: String
    let sessionID: String
    let createdAt: Date
    let percentDelta: Double
    let euroDelta: Decimal?
    let adjustedMidNet: Decimal
    let reason: AdjustmentReason
    let target: AdjustmentTarget
    let status: LearningStatus
    let note: String

    init(id: String = UUID().uuidString, sessionID: String, createdAt: Date = Date(), percentDelta: Double, euroDelta: Decimal?, adjustedMidNet: Decimal, reason: AdjustmentReason, target: AdjustmentTarget, status: LearningStatus = .active, note: String = "") {
        self.id = id
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.percentDelta = percentDelta
        self.euroDelta = euroDelta
        self.adjustedMidNet = adjustedMidNet
        self.reason = reason
        self.target = target
        self.status = status
        self.note = note
    }
}
