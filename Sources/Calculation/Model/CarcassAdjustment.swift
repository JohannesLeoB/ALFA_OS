import Foundation

struct CarcassAdjustment: Equatable, Identifiable, Sendable {
    let id: String
    let sessionID: String
    let createdAt: Date
    let target: CarcassCalibrationTarget
    let modelValue: Double
    let observedValue: Double
    let reason: AdjustmentReason
    let note: String
    let status: LearningStatus

    init(id: String = UUID().uuidString, sessionID: String, createdAt: Date = Date(),
         target: CarcassCalibrationTarget, modelValue: Double, observedValue: Double,
         reason: AdjustmentReason, note: String = "", status: LearningStatus = .active) {
        self.id = id
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.target = target
        self.modelValue = modelValue
        self.observedValue = observedValue
        self.reason = reason
        self.note = note
        self.status = status
    }

    var percentDelta: Double {
        modelValue == 0 ? 0 : (observedValue - modelValue) / modelValue * 100
    }
}
