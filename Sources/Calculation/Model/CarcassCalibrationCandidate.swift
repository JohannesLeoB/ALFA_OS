import Foundation

struct CarcassCalibrationCandidate: Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let target: CarcassCalibrationTarget
    let sampleCount: Int
    let weightedPercentDelta: Double
    let currentValue: Double
    let proposedValue: Double
    let adjustmentIDs: [String]
    let status: LearningStatus
    let note: Notice

    init(id: String, createdAt: Date = Date(), target: CarcassCalibrationTarget, sampleCount: Int,
         weightedPercentDelta: Double, currentValue: Double, proposedValue: Double,
         adjustmentIDs: [String], status: LearningStatus, note: Notice) {
        self.id = id
        self.createdAt = createdAt
        self.target = target
        self.sampleCount = sampleCount
        self.weightedPercentDelta = weightedPercentDelta
        self.currentValue = currentValue
        self.proposedValue = proposedValue
        self.adjustmentIDs = adjustmentIDs
        self.status = status
        self.note = note
    }
}
