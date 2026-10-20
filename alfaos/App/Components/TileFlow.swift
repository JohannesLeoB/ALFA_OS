import ShellCore
import SwiftUI

struct TileFlow: Layout {
    let minimum: Double
    let gap: Double
    let height: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minimum
        let count = TileGrid.columns(width: Double(width), minimum: minimum, gap: gap)
        let rows = (subviews.count + count - 1) / count
        let total = rows == 0 ? 0 : Double(rows) * height + Double(rows - 1) * gap
        return CGSize(width: width, height: CGFloat(total))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = TileGrid.columns(width: Double(bounds.width), minimum: minimum, gap: gap)
        let cell = TileGrid.columnWidth(width: Double(bounds.width), count: count, gap: gap)
        for (index, view) in subviews.enumerated() {
            let x = bounds.minX + CGFloat(Double(index % count) * (cell + gap))
            let y = bounds.minY + CGFloat(Double(index / count) * (height + gap))
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: CGFloat(cell), height: CGFloat(height)))
        }
    }
}
