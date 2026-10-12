import CoreGraphics
import Foundation

/// What a point of the view hits in a fan.
public enum FanTarget: Equatable, Sendable {
    case rivet
    case blade(Int)
    case nothing
}

extension FanGeometry {
    /// What lies under `point` in a view of `size` when the fan is at `stage`. The rivet comes first. Of several
    /// blades under the point, the one drawn last (highest index) wins, as it is on top.
    public func target(at point: CGPoint, stage: FanStage, in size: CGSize) -> FanTarget {
        let pivot = pivot(for: stage, in: size)
        let dx = Double(point.x - pivot.x), dy = Double(point.y - pivot.y)
        if (dx * dx + dy * dy).squareRoot() <= holeRadius * FanGeometry.rivetReach {
            return .rivet
        }
        for index in (0..<count).reversed() {
            // Undo the turn of the blade: rotate the offset back by its angle.
            let turn = angle(of: index, at: stage) * .pi / 180
            let cosine = cos(turn), sine = sin(turn)
            let local = CGPoint(x: CGFloat(dx * cosine + dy * sine), y: CGFloat(-dx * sine + dy * cosine))
            if bladeRect.contains(local) {
                return .blade(index)
            }
        }
        return .nothing
    }
}
