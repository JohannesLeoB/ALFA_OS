import Foundation

/// Which way a panel slides when its palette changes: forward when the new palette lies after the old one.
public enum PanelDirection: Equatable, Sendable {
    case forward, backward, still

    /// Direction from the index of the old palette to the index of the new one.
    public init(from old: Int, to new: Int) {
        if new > old {
            self = .forward
        } else if new < old {
            self = .backward
        } else {
            self = .still
        }
    }

    /// Sign of the slide: +1 enters from the trailing side, -1 from the leading side, 0 does not slide.
    public var sign: Double {
        switch self {
        case .forward: 1
        case .backward: -1
        case .still: 0
        }
    }
}
