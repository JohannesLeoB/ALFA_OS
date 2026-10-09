import Foundation

/// The stages of a fan. Shut: one upright stack at the home place. Align: the upright stack slid to the open place.
/// Flat: the stack turned flat. Open: the blades spread into the half circle.
public enum FanStage: Equatable, Sendable {
    case shut, align, flat, open
}

/// One step of a motion: the stage it arrives at and how long the step takes.
public struct FanStep: Equatable, Sendable {
    public let stage: FanStage
    public let milliseconds: Int

    public init(stage: FanStage, milliseconds: Int) {
        self.stage = stage
        self.milliseconds = milliseconds
    }

    /// Duration of the step. With reduced motion the stage changes at once, without a transition.
    public func effectiveMilliseconds(reduceMotion: Bool) -> Int {
        reduceMotion ? 0 : milliseconds
    }
}

/// A cubic Bezier curve from (0, 0) to (1, 1), written as in CSS. The x values of the two inner points lie in 0...1.
public struct TimingCurve: Equatable, Sendable {
    public let x1: Double
    public let y1: Double
    public let x2: Double
    public let y2: Double

    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    /// Progress along the curve for the time fraction `time`, both from 0 to 1.
    public func value(at time: Double) -> Double {
        let target = min(1, max(0, time))
        var low = 0.0, high = 1.0
        for _ in 0..<60 {
            let middle = (low + high) / 2
            if TimingCurve.bezier(middle, x1, x2) < target {
                low = middle
            } else {
                high = middle
            }
        }
        return TimingCurve.bezier((low + high) / 2, y1, y2)
    }

    private static func bezier(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
        let u = 1 - s
        return 3 * u * u * s * p1 + 3 * u * s * s * p2 + s * s * s
    }
}

/// The two motions of the fan. Opening runs three steps: slide to the open place, turn flat, sweep open.
/// Closing runs the same steps backwards, and each step is quicker than the one it mirrors.
public enum FanMotion {
    /// Steps in milliseconds. Each step takes 150 to 300 milliseconds.
    public static let alignMilliseconds = 240
    public static let turnMilliseconds = 200
    public static let sweepMilliseconds = 300
    public static let closeSweepMilliseconds = 240
    public static let closeTurnMilliseconds = 160
    public static let closeAlignMilliseconds = 192

    /// The range of one step in milliseconds.
    public static let stepRange = 150...300

    public static let opening: [FanStep] = [
        FanStep(stage: .align, milliseconds: alignMilliseconds),
        FanStep(stage: .flat, milliseconds: turnMilliseconds),
        FanStep(stage: .open, milliseconds: sweepMilliseconds),
    ]

    public static let closing: [FanStep] = [
        FanStep(stage: .flat, milliseconds: closeSweepMilliseconds),
        FanStep(stage: .align, milliseconds: closeTurnMilliseconds),
        FanStep(stage: .shut, milliseconds: closeAlignMilliseconds),
    ]

    /// Easing of every step: an ease-out quint.
    public static let easing = TimingCurve(x1: 0.23, y1: 1, x2: 0.32, y2: 1)

    /// The steps that a tap takes the fan through: opening from shut, closing from open.
    /// During a transition there is no step, so the tap does nothing.
    public static func toggled(from stage: FanStage) -> [FanStep]? {
        switch stage {
        case .shut: return opening
        case .open: return closing
        case .align, .flat: return nil
        }
    }
}
