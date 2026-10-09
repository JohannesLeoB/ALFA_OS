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
        if let box = ContextBarPlacement.box(of: canvas.selectionFrames) {
            // The frame covers the canvas. Its empty parts pass clicks through to the canvas,
            // and only the bar and its entries take them.
            GeometryReader { proxy in
                let center = ContextBarPlacement.center(of: box,
                                                        barWidth: Double(barSize.width),
                                                        barHeight: Double(barSize.height),
                                                        containerWidth: Double(proxy.size.width),
                                                        gap: Double(theme.space(.s2)))
                ContextBarView(store: canvas.store)
                    .onGeometryChange(for: CGSize.self, of: \.size) { barSize = $0 }
                    .position(x: center.x, y: center.y)
            }
        }
    }
}
