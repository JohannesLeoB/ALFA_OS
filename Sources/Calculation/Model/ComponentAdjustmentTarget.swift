import Foundation

struct ComponentAdjustmentTarget: Equatable, Identifiable, Sendable {
    let id: String
    let adjustmentID: String
    let sessionComponentID: String?
    let target: AdjustmentTarget
    let percentDelta: Double
    let status: LearningStatus

    init(id: String = UUID().uuidString, adjustmentID: String, sessionComponentID: String?, target: AdjustmentTarget, percentDelta: Double, status: LearningStatus = .active) {
        self.id = id
        self.adjustmentID = adjustmentID
        self.sessionComponentID = sessionComponentID
        self.target = target
        self.percentDelta = percentDelta
        self.status = status
    }
}
