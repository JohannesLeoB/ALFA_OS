import CoreGraphics

/// Frames of the blob menu in the coordinates of its container. Every size and margin comes from the caller,
/// so the values of the interface stay in the theme.
public enum BlobGeometry {
    /// The frame of the blob at its edge. For the row, the frame covers all blobs and their gaps.
    /// Without a pin, the menu sits at the top center.
    public static func anchor(layout: BlobLayout, count: Int, blob: CGSize, gap: CGFloat,
                              edge: BlobEdge, container: CGSize, margin: CGFloat) -> CGRect {
        let slots = layout == .bar ? max(count, 1) : 1
        let run = CGFloat(slots)
        let spacing = gap * CGFloat(slots - 1)
        let width = edge.isHorizontal ? blob.width * run + spacing : blob.width
        let height = edge.isHorizontal ? blob.height : blob.height * run + spacing
        return CGRect(origin: origin(of: CGSize(width: width, height: height), at: edge,
                                     container: container, margin: margin),
                      size: CGSize(width: width, height: height))
    }

    /// The frame of each blob of the row, in palette order, inside the anchor frame.
    public static func slots(count: Int, blob: CGSize, gap: CGFloat, edge: BlobEdge, anchor: CGRect) -> [CGRect] {
        (0..<max(count, 0)).map { index in
            let step = CGFloat(index) * (edge.isHorizontal ? blob.width + gap : blob.height + gap)
            let x = edge.isHorizontal ? anchor.minX + step : anchor.minX
            let y = edge.isHorizontal ? anchor.minY : anchor.minY + step
            return CGRect(x: x, y: y, width: blob.width, height: blob.height)
        }
    }

    /// The frame of the open palette. It spreads away from the edge, centered on the anchor and kept inside
    /// the container.
    public static func card(size: CGSize, anchor: CGRect, edge: BlobEdge,
                            container: CGSize, margin: CGFloat, gap: CGFloat) -> CGRect {
        let raw: CGPoint
        switch edge {
        case .top:
            raw = CGPoint(x: anchor.midX - size.width / 2, y: anchor.maxY + gap)
        case .bottom:
            raw = CGPoint(x: anchor.midX - size.width / 2, y: anchor.minY - gap - size.height)
        case .leading:
            raw = CGPoint(x: anchor.maxX + gap, y: anchor.midY - size.height / 2)
        case .trailing:
            raw = CGPoint(x: anchor.minX - gap - size.width, y: anchor.midY - size.height / 2)
        }
        let x = clamp(raw.x, size.width, within: container.width, margin: margin)
        let y = clamp(raw.y, size.height, within: container.height, margin: margin)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// The edge that is nearest to a point, for example the center of the blob when it is pinned.
    /// On a tie, the earlier edge in `BlobEdge.allCases` wins.
    public static func nearestEdge(to point: CGPoint, in container: CGSize) -> BlobEdge {
        let distances: [(edge: BlobEdge, distance: CGFloat)] = [
            (.top, point.y),
            (.bottom, container.height - point.y),
            (.leading, point.x),
            (.trailing, container.width - point.x),
        ]
        return distances.min { $0.distance < $1.distance }?.edge ?? .top
    }

    // MARK: - Helpers

    private static func origin(of size: CGSize, at edge: BlobEdge, container: CGSize, margin: CGFloat) -> CGPoint {
        switch edge {
        case .top:
            CGPoint(x: (container.width - size.width) / 2, y: margin)
        case .bottom:
            CGPoint(x: (container.width - size.width) / 2, y: container.height - margin - size.height)
        case .leading:
            CGPoint(x: margin, y: (container.height - size.height) / 2)
        case .trailing:
            CGPoint(x: container.width - margin - size.width, y: (container.height - size.height) / 2)
        }
    }

    /// Places a length inside the container with a margin on both sides. A length that does not fit
    /// is pushed to the start margin.
    private static func clamp(_ value: CGFloat, _ length: CGFloat, within total: CGFloat, margin: CGFloat) -> CGFloat {
        let highest = max(margin, total - margin - length)
        return min(max(value, margin), highest)
    }
}
