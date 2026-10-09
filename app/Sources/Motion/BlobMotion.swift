import Foundation

/// The kinds of change that the blob menu animates.
public enum BlobTransition: Equatable, Sendable {
    case expand, collapse, switchPalette, layout, pin
}

/// Durations of the blob menu. Each one is a reply to a tap, so each one is 150 to 300 milliseconds.
public enum BlobMotion {
    public static let expandMilliseconds = 240
    public static let collapseMilliseconds = 200
    public static let switchMilliseconds = 180
    public static let layoutMilliseconds = 260
    public static let pinMilliseconds = 280

    /// The range of one transition in milliseconds.
    public static let range = 150...300

    /// Easing of every transition: an ease-out quint, as in the fan.
    public static let easing = TimingCurve(x1: 0.23, y1: 1, x2: 0.32, y2: 1)

    /// Duration in milliseconds. With reduced motion the change happens at once.
    public static func milliseconds(for transition: BlobTransition, reduceMotion: Bool) -> Int {
        if reduceMotion { return 0 }
        switch transition {
        case .expand: return expandMilliseconds
        case .collapse: return collapseMilliseconds
        case .switchPalette: return switchMilliseconds
        case .layout: return layoutMilliseconds
        case .pin: return pinMilliseconds
        }
    }

    /// The transition that a change of state runs, or nil when nothing animates. A pin or a layout change
    /// counts first, then the palette: opening, closing or switching to another palette.
    public static func transition(from before: BlobMenu, to after: BlobMenu) -> BlobTransition? {
        if before.pin != after.pin { return .pin }
        if before.layout != after.layout { return .layout }
        switch (before.open, after.open) {
        case (nil, nil): return nil
        case (nil, .some): return .expand
        case (.some, nil): return .collapse
        case let (.some(old), .some(new)): return old == new ? nil : .switchPalette
        }
    }
}
