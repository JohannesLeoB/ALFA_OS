import Shell
import SwiftUI

private struct PulseEffect: ViewModifier, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let peak = SheetValues.pulseScale
        let p = min(1, max(0, progress))
        let mid = SheetValues.keyframeMiddle
        let scale = p < mid ? 1 + (peak - 1) * p / mid : peak - (peak - 1) * (p - mid) / (1 - mid)
        content.scaleEffect(CGFloat(scale))
    }
}

extension View {
    func pulse(progress: Double) -> some View {
        modifier(PulseEffect(progress: progress))
    }
}
