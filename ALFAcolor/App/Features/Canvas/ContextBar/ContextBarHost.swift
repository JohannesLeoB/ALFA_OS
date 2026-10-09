import SwiftUI
import ALFAcolorCore
import AppTheme
import BoardModel

/// Places the context bar above the selection, or below it when there is no room above.
/// The bar stays inside the canvas at the sides. It is shown only while something is selected.
struct ContextBarHost: View {
    var canvas: CanvasController

    @Environment(\.theme) private var theme
    @State private var barSize: CGSize = .zero

    var body: some View {
        if let box = Self.box(of: canvas.selectionFrames) {
            GeometryReader { proxy in
                let center = center(of: box, container: proxy.size)
                ContextBarView(store: canvas.store)
                    .onGeometryChange(for: CGSize.self, of: \.size) { barSize = $0 }
                    .allowsHitTesting(true)
                    .position(x: center.x, y: center.y)
            }
            // The frame covers the canvas; only the bar takes pointer input, so the canvas keeps its gestures.
            .allowsHitTesting(false)
        }
    }

    /// The center of the bar on the canvas, from the box of the selection and the measured size of the bar.
    private func center(of box: Rect, container: CGSize) -> CGPoint {
        let gap = theme.space(.s2)
        var top = box.y - gap - barSize.height
        if top < 0 { top = box.maxY + gap }
        let left = min(max(box.center.x - barSize.width / 2, 0), max(container.width - barSize.width, 0))
        return CGPoint(x: left + barSize.width / 2, y: top + barSize.height / 2)
    }

    /// The box around all selected frames, in canvas points. Nil when nothing is selected.
    private static func box(of frames: [Rect]) -> Rect? {
        guard let first = frames.first else { return nil }
        let minX = frames.reduce(first.x) { min($0, $1.x) }
        let minY = frames.reduce(first.y) { min($0, $1.y) }
        let maxX = frames.reduce(first.maxX) { max($0, $1.maxX) }
        let maxY = frames.reduce(first.maxY) { max($0, $1.maxY) }
        return Rect(x: minX, y: minY, w: maxX - minX, h: maxY - minY)
    }
}
