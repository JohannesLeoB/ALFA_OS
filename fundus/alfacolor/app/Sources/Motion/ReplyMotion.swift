import Foundation

/// The reply motions outside the blob menu and the fan. Each one answers an action.
/// The palette switch of the blob menu keeps its own timing in `BlobMotion`.
public enum ReplyMotion: CaseIterable, Sendable {
    /// The digits of a number roll to the new value.
    case roll
    /// One pass of a trail round the item that was picked.
    case trail

    /// Duration in milliseconds. Each one is 150 to 300 milliseconds.
    public var milliseconds: Int {
        switch self {
        case .roll: 240
        case .trail: 300
        }
    }

    /// The range of one reply motion in milliseconds.
    public static let range = 150...300

    /// Easing of every reply motion: an ease-out quint, as in the fan and the blob menu.
    public static let easing = TimingCurve(x1: 0.23, y1: 1, x2: 0.32, y2: 1)

    /// Duration in milliseconds. With reduced motion the change happens at once.
    public func effectiveMilliseconds(reduceMotion: Bool) -> Int {
        reduceMotion ? 0 : milliseconds
    }
}
