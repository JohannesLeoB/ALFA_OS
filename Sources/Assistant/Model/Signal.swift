public enum Signal: Sendable, Equatable {
    case projectFocused(projectID: String)
    case driveFileAdded(projectID: String, fileName: String)
    case offerDetected(projectID: String, label: String)
    case drawingDetected(projectID: String, label: String)
    case reviewSuggested(projectID: String, label: String)
    case budgetThresholdCrossed(projectID: String, ratio: Double)
    case deadlineNear(projectID: String, days: Int)
    case taskDueSoon(projectID: String, taskName: String, days: Int)

    var projectNumber: String {
        switch self {
        case .projectFocused(let id),
             .driveFileAdded(let id, _),
             .offerDetected(let id, _),
             .drawingDetected(let id, _),
             .reviewSuggested(let id, _),
             .budgetThresholdCrossed(let id, _),
             .deadlineNear(let id, _),
             .taskDueSoon(let id, _, _):
            id
        }
    }
}
