struct LearningSnapshot: Sendable, Equatable {
    let sessions: Int
    let adjustments: Int
    let outliers: Int
    let activeFactors: [EstimationFactor]
    let candidates: [EstimationFactor]

    init(sessions: Int, adjustments: Int, outliers: Int, activeFactors: [EstimationFactor], candidates: [EstimationFactor]) {
        self.sessions = sessions
        self.adjustments = adjustments
        self.outliers = outliers
        self.activeFactors = activeFactors
        self.candidates = candidates
    }

    var isEmpty: Bool { activeFactors.isEmpty && candidates.isEmpty }
}

struct EstimationFactor: Sendable, Equatable, Identifiable {
    let id: String
    let reason: AdjustmentReason
    let target: AdjustmentTarget
    let percent: Double
    let sampleCount: Int
    let status: LearningStatus

    init(id: String, reason: AdjustmentReason, target: AdjustmentTarget, percent: Double, sampleCount: Int, status: LearningStatus) {
        self.id = id
        self.reason = reason
        self.target = target
        self.percent = percent
        self.sampleCount = sampleCount
        self.status = status
    }
}
