import Foundation
import ALFAcolorCore

/// The edges of the other items, sorted on each axis. A snap reads only the items near the moving
/// rectangle, so one call costs about as much as the items it finds. Built once for a set of targets.
struct SnapIndex: Equatable, Sendable {
    /// Values of one kind of edge on one axis, sorted, with the item that each value belongs to.
    struct Sorted: Equatable, Sendable {
        private(set) var values: [Double] = []
        private(set) var items: [Int] = []

        init(_ pairs: [(value: Double, item: Int)]) {
            let sorted = pairs.sorted { $0.value < $1.value }
            values = sorted.map(\.value)
            items = sorted.map(\.item)
        }

        /// The positions whose values lie in the closed range `low...high`.
        func positions(from low: Double, through high: Double) -> Range<Int> {
            let start = firstAtLeast(low)
            return start..<max(start, firstAbove(high))
        }

        /// The first position whose value is not below `key`.
        private func firstAtLeast(_ key: Double) -> Int {
            var low = 0, high = values.count
            while low < high {
                let middle = (low + high) / 2
                if values[middle] < key { low = middle + 1 } else { high = middle }
            }
            return low
        }

        /// The first position whose value is above `key`.
        private func firstAbove(_ key: Double) -> Int {
            var low = 0, high = values.count
            while low < high {
                let middle = (low + high) / 2
                if values[middle] <= key { low = middle + 1 } else { high = middle }
            }
            return low
        }
    }

    /// The index of one axis.
    struct Axis: Equatable, Sendable {
        /// The lower edge, the middle and the upper edge of every item.
        var edges: Sorted
        /// The upper edge of every item: the items that end before a position.
        var uppers: Sorted
        /// The lower edge of every item: the items that start after a position.
        var lowers: Sorted
    }

    private(set) var x: Axis
    private(set) var y: Axis

    /// Items that are not finite are left out.
    init(rects: [Rect]) {
        func axis(_ lower: (Rect) -> Double, _ upper: (Rect) -> Double) -> Axis {
            var edges: [(value: Double, item: Int)] = []
            var lowers: [(value: Double, item: Int)] = []
            var uppers: [(value: Double, item: Int)] = []
            for (item, rect) in rects.enumerated() where rect.isFinite {
                let low = lower(rect), high = upper(rect)
                edges.append((low, item))
                edges.append(((low + high) / 2, item))
                edges.append((high, item))
                lowers.append((low, item))
                uppers.append((high, item))
            }
            return Axis(edges: Sorted(edges), uppers: Sorted(uppers), lowers: Sorted(lowers))
        }
        x = axis({ $0.x }, { $0.maxX })
        y = axis({ $0.y }, { $0.maxY })
    }

    func axis(_ along: Along) -> Axis { along == .x ? x : y }
}
