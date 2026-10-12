import Foundation

public enum WidgetSource: String, Codable, Sendable, CaseIterable {
    case drive
    case people
    case calendar
    case tasks
    case cash
    case notes
    case assistant
}

public enum WidgetSignal: Sendable, Equatable {
    case projectFocused(projectID: String)
    case driveFileAdded(projectID: String, fileName: String)
    case offerDetected(projectID: String, label: String)
    case drawingDetected(projectID: String, label: String)
    case reviewSuggested(projectID: String, label: String)
    case budgetThresholdCrossed(projectID: String, ratio: Double)
    case deadlineNear(projectID: String, days: Int)

    case myClickUpTaskDueSoon(projectID: String, taskName: String, days: Int)

    public var projectNumber: String {
        switch self {
        case .projectFocused(let p),
             .driveFileAdded(let p, _),
             .offerDetected(let p, _),
             .drawingDetected(let p, _),
             .reviewSuggested(let p, _),
             .budgetThresholdCrossed(let p, _),
             .deadlineNear(let p, _),
             .myClickUpTaskDueSoon(let p, _, _):
            p
        }
    }
}
