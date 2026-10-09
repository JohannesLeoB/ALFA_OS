import SwiftUI
import AppTheme
import Motion

extension View {
    /// Runs one pass of a light trail round the view each time `on` turns true. Radius infinity gives a circle or a pill.
    /// Nothing runs with reduced motion.
    func borderTrailPass(on: Bool, radius: CGFloat) -> some View {
        modifier(BorderTrailPass(on: on, radius: radius))
    }
}

private struct BorderTrailPass: ViewModifier {
    let on: Bool
    let radius: CGFloat

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Counts the passes. Each pass is a new view, so it starts again from the beginning.
    @State private var passes = 0

    func body(content: Content) -> some View {
        content
            .onChange(of: on) { _, isOn in
                if isOn && !reduceMotion {
                    passes += 1
                }
            }
            .overlay {
                if passes > 0 {
                    TrailPass(radius: radius, lineWidth: theme.space(.s1), color: theme.color(.accent, scheme))
                        .id(passes)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// One pass of the trail. It runs from the start to the end of the outline and then leaves no mark.
private struct TrailPass: View {
    let radius: CGFloat
    let lineWidth: CGFloat
    let color: Color

    @State private var progress = 0.0

    var body: some View {
        TrailShape(progress: progress, radius: radius)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .onAppear {
                withAnimation(ReplyMotion.trail.animation(reduceMotion: false)) {
                    progress = 1 + TrailWindow.length
                }
            }
    }
}

/// The lit part of the outline at a progress. Animating the progress moves the trail round the outline.
private struct TrailShape: Shape {
    var progress: Double
    let radius: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard let range = TrailWindow.range(progress: progress) else { return Path() }
        let outline = Path(TrailOutline.path(width: rect.width, height: rect.height, radius: radius))
        return outline.trimmedPath(from: CGFloat(range.lowerBound), to: CGFloat(range.upperBound))
    }
}
