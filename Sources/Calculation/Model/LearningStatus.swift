enum LearningStatus: String, CaseIterable, Sendable {
    case active
    case inactive
    case superseded
    case promoted
    case candidate
    case strongCandidate = "strong_candidate"
    case reviewOutlier = "review_outlier"
}
