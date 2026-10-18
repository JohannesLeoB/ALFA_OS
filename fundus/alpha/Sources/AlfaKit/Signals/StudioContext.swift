import Foundation
import Observation

@Observable
public final class StudioContext {
    public private(set) var focusedProjectID: String?
    public private(set) var signals: [WidgetSignal] = []

    public private(set) var mailComposeRequest: String?

    public private(set) var onboardingReopenRequested = false

    public private(set) var katalogSucheRequest: String?

    public init() {}

    public func requestKatalogSuche(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        katalogSucheRequest = trimmed
    }

    public func clearKatalogSuche() { katalogSucheRequest = nil }

    public func requestOnboardingReopen() { onboardingReopenRequested = true }

    public func clearOnboardingReopen() { onboardingReopenRequested = false }

    public func requestMailCompose(to email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mailComposeRequest = trimmed
    }

    public func requestMailComposeBlank() {
        mailComposeRequest = ""
    }

    public func unfocusProject() {
        focusedProjectID = nil
    }

    public func clearMailComposeRequest() {
        mailComposeRequest = nil
    }

    private static let maxSignals = 200

    public func focus(project id: String) {
        let changed = focusedProjectID != id
        focusedProjectID = id
        if changed { emit(.projectFocused(projectID: id)) }
    }

    public func emit(_ signal: WidgetSignal) {
        signals.append(signal)
        if let derived = Mediator.derive(from: signal) {
            signals.append(derived)
        }
        if signals.count > Self.maxSignals {
            signals.removeFirst(signals.count - Self.maxSignals)
        }
    }

    public func isFocused(_ projectID: String) -> Bool {
        focusedProjectID == projectID
    }

    public func signals(for projectID: String) -> [WidgetSignal] {
        signals.filter { signalProjectID($0) == projectID }
    }

    private func signalProjectID(_ s: WidgetSignal) -> String {
        switch s {
        case let .projectFocused(p),
             let .driveFileAdded(p, _),
             let .offerDetected(p, _),
             let .drawingDetected(p, _),
             let .reviewSuggested(p, _),
             let .budgetThresholdCrossed(p, _),
             let .deadlineNear(p, _),
             let .myClickUpTaskDueSoon(p, _, _):
            return p
        }
    }
}
