import Shell
import SwiftUI

private struct SearchFade: ViewModifier, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let start = SheetValues.tapeFadeAt
        content.opacity(progress < start ? 0 : (progress - start) / (1 - start))
    }
}

extension View {
    func searchFade(progress: Double) -> some View {
        modifier(SearchFade(progress: progress))
    }
}
