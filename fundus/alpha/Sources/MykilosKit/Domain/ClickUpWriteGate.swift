import Foundation

public enum ClickUpLifecycleSyncError: Error, Sendable, Equatable, LocalizedError {
    case keinAnkerTask
    case projectPhaseFeldFehlt

    public var errorDescription: String? {
        switch self {
        case .keinAnkerTask:
            return "Kein Anker-Task mit Custom Fields in dieser ClickUp-Liste gefunden."
        case .projectPhaseFeldFehlt:
            return "Custom Field project_phase existiert nicht (mehr) auf dem Anker-Task."
        }
    }
}
