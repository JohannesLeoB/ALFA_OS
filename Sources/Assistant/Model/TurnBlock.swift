import Foundation

public enum TurnBlock: Equatable, Sendable {
    case activity(label: String, failed: Bool)
    case text(String)
    case draft(DraftSummary)
    case estimate(minNet: Double, maxNet: Double)
    case breakdown(lines: Int)
    case file(String)
    case unreadable

    var isFile: Bool {
        if case .file = self { true } else { false }
    }
}
