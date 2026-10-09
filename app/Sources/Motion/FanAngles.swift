import Foundation

extension FanGeometry {
    /// Angle between neighbouring blades when open, in degrees. Zero for a single blade.
    public var openStep: Double {
        count > 1 ? spread / Double(count - 1) : 0
    }

    /// Turn of one blade at `stage`, in degrees clockwise from upright. Flat blades share the first blade's angle,
    /// so the stack lies flat in one place. Open, blade `index` lies `index` steps from the first one.
    public func angle(of index: Int, at stage: FanStage) -> Double {
        let first = -spread / 2
        switch stage {
        case .shut, .align:
            return 0
        case .flat:
            return first
        case .open:
            return first + Double(index) * openStep
        }
    }

    /// Turn of one blade between two stages, at `progress` from 0 to 1 before any easing is applied.
    /// Every blade covers the same share of its own way, so the gaps between blades are equal in every frame.
    public func angle(of index: Int, from start: FanStage, to end: FanStage, progress: Double) -> Double {
        let from = angle(of: index, at: start)
        let to = angle(of: index, at: end)
        return from + (to - from) * progress
    }

    /// Strength of the contact shadow of each blade at `stage`, from 0 to 1. None while the blades stack,
    /// full once the gaps reach `contactFullDegrees`. The shadow of the whole fan is not affected.
    public func contactShade(at stage: FanStage) -> Double {
        guard stage == .open else { return 0 }
        return min(1, max(0, openStep / FanGeometry.contactFullDegrees))
    }
}
