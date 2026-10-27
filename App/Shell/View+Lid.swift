import Design
import Shell
import SwiftUI

private struct LidEffect: ViewModifier, Animatable {
    var progress: Double
    let kind: LidKind?
    var scale: Double
    var shift: Double

    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(progress, AnimatablePair(scale, shift)) }
        set {
            progress = newValue.first
            scale = newValue.second.first
            shift = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        if let kind, progress < 1 {
            content.scaleEffect(x: 1, y: CGFloat(Self.value(kind, progress)))
        } else {
            content.scaleEffect(x: 1, y: CGFloat(scale)).offset(y: CGFloat(shift))
        }
    }

    static func value(_ kind: LidKind, _ t: Double) -> Double {
        let p = min(1, max(0, t))
        switch kind {
        case .blink:
            let low = SheetValues.blinkScale
            let mid = SheetValues.keyframeMiddle
            return p < mid ? 1 - (1 - low) * p / mid : low + (1 - low) * (p - mid) / (1 - mid)
        case .wink:
            let low = SheetValues.winkScale
            let close = SheetValues.winkCloseAt
            let open = SheetValues.winkOpenAt
            if p < close { return 1 - (1 - low) * p / close }
            if p < open { return low }
            return low + (1 - low) * (p - open) / (1 - open)
        }
    }
}

extension View {
    func lidShift(progress: Double, kind: LidKind?, scale: Double, shift: Double) -> some View {
        modifier(LidEffect(progress: progress, kind: kind, scale: scale, shift: shift))
    }
}
