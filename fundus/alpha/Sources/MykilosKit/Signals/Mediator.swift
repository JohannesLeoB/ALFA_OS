import Foundation

public enum Mediator {
    public static func derive(from signal: WidgetSignal) -> WidgetSignal? {
        switch signal {
        case let .offerDetected(projectID, label):
            return .reviewSuggested(projectID: projectID, label: label)
        default:
            return nil
        }
    }
}
