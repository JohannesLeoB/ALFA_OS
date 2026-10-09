import SwiftUI
import Motion

extension ReplyMotion {
    /// The animation of the motion, with the easing of `Motion`. Nil with reduced motion, so the change is instant.
    func animation(reduceMotion: Bool) -> Animation? {
        let milliseconds = effectiveMilliseconds(reduceMotion: reduceMotion)
        guard milliseconds > 0 else { return nil }
        let curve = ReplyMotion.easing
        return .timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: Double(milliseconds) / 1000)
    }
}
