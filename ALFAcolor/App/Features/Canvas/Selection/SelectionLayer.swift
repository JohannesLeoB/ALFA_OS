import SwiftUI
import AppTheme
import BoardModel

/// What shows that something is selected: an outline around each selected item, the box and the eight handles,
/// the lasso, and the ring around an item whose text is edited. Lines are as wide on the screen at every zoom.
/// The layer takes no input; the pointer is handled by `SelectionInput`.
struct SelectionLayer: View {
    var interaction: CanvasInteraction

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let view = interaction.controller.viewport
        let editedID = interaction.editing?.itemID
        let outlines = interaction.outlineRects.map(view.canvasRect(of:))
        let edited = editedID.flatMap { interaction.store.item($0) }.map { view.canvasRect(of: $0.rect) }
        let lasso = interaction.lasso.map(view.canvasRect(of:))
        let box = interaction.outlineRects.count > 1 ? interaction.handleRectOnCanvas : nil
        let handles = interaction.handles
        let size = interaction.handleSize
        let ink = theme.color(.text, scheme)
        let coral = theme.color(.coral, scheme)
        let paper = theme.color(.surface, scheme)
        Canvas { context, _ in
            let gap = SelectionStyle.outlineGap
            for rect in outlines where edited != rect {
                let outer = CGRect(x: rect.x - gap, y: rect.y - gap, width: rect.w + 2 * gap, height: rect.h + 2 * gap)
                context.stroke(Path(outer), with: .color(ink), lineWidth: SelectionStyle.outlineWidth)
            }
            if let edited {
                let ring = CGRect(x: edited.x, y: edited.y, width: edited.w, height: edited.h)
                context.stroke(Path(ring), with: .color(coral), lineWidth: SelectionStyle.focusRingWidth)
            }
            if let box {
                context.stroke(Path(CGRect(x: box.x, y: box.y, width: box.w, height: box.h)), with: .color(ink), lineWidth: SelectionStyle.lineWidth)
            }
            for entry in handles {
                let square = CGRect(x: entry.x - size / 2, y: entry.y - size / 2, width: size, height: size)
                context.fill(Path(square), with: .color(paper))
                context.stroke(Path(square), with: .color(ink), lineWidth: SelectionStyle.lineWidth)
            }
            if let lasso {
                let area = Path(CGRect(x: lasso.x, y: lasso.y, width: lasso.w, height: lasso.h))
                context.fill(area, with: .color(coral.opacity(SelectionStyle.lassoFillOpacity)))
                context.stroke(area, with: .color(coral), lineWidth: SelectionStyle.lineWidth)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
