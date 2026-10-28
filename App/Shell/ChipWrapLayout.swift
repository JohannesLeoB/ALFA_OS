import SwiftUI

struct ChipWrapLayout: Layout {
    let gap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let used = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? used, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = fitted(subviews[index], width: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + gap
            }
        }
    }

    private func fitted(_ subview: LayoutSubview, width: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        return ideal.width > width ? subview.sizeThatFits(ProposedViewSize(width: width, height: ideal.height)) : ideal
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [WrapRow] {
        var rows: [WrapRow] = []
        var current = WrapRow(y: 0)
        for index in subviews.indices {
            let size = fitted(subviews[index], width: width)
            let next = current.items.isEmpty ? size.width : current.width + gap + size.width
            if next > width && !current.items.isEmpty {
                rows.append(current)
                current = WrapRow(y: current.y + current.height + gap)
            }
            current.width = current.items.isEmpty ? size.width : current.width + gap + size.width
            current.height = max(current.height, size.height)
            current.items.append(index)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

private struct WrapRow {
    let y: CGFloat
    var width: CGFloat = 0
    var height: CGFloat = 0
    var items: [Int] = []
}
