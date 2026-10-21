import Foundation

public struct Dimension: Sendable, Equatable {
    public var from: Double
    public var to: Double
    public var offsetPaper: Double
    public var text: String
    public var horizontal: Bool
    public var total: Bool
}

enum Dimensioner {
    static func chain(edges: [Double], datum: Double? = nil, scale n: Double,
                      minPaperLen: Double, tolerance: Double = 0.5,
                      baseOffset: Double, step: Double, horizontal: Bool) -> [Dimension] {
        guard n.isFinite, n > 0 else { return [] }
        let clamp = { (v: Double) in min(Validate.limit, max(-Validate.limit, v)) }
        var raw = edges.filter(\.isFinite).map(clamp)
        let anchor = datum.flatMap { $0.isFinite ? clamp($0) : nil }
        if let anchor { raw.append(anchor) }
        raw.sort()

        var clusters: [(value: Double, datum: Bool)] = []
        var start = -Double.infinity
        for v in raw {
            let isDatum = anchor.map { abs($0 - v) <= tolerance } ?? false
            if v - start <= tolerance, !clusters.isEmpty {
                if isDatum { clusters[clusters.count - 1] = (v.rounded(), true) }
                continue
            }
            start = v
            clusters.append((v.rounded(), isDatum))
        }
        guard clusters.count > 1 else { return [] }

        let minNatural = minPaperLen * n
        var kept = [clusters[0]]
        for c in clusters.dropFirst().dropLast() {
            if c.value - kept[kept.count - 1].value >= minNatural || c.datum { kept.append(c) }
        }
        let last = clusters[clusters.count - 1]
        while kept.count > 1, last.value - kept[kept.count - 1].value < minNatural, !kept[kept.count - 1].datum {
            kept.removeLast()
        }
        kept.append(last)

        var out: [Dimension] = []
        for i in 0..<(kept.count - 1) {
            out.append(Dimension(from: kept[i].value, to: kept[i + 1].value, offsetPaper: baseOffset,
                                 text: label(kept[i + 1].value - kept[i].value), horizontal: horizontal, total: false))
        }
        if kept.count > 2 {
            out.append(Dimension(from: kept[0].value, to: kept[kept.count - 1].value, offsetPaper: baseOffset + step,
                                 text: label(kept[kept.count - 1].value - kept[0].value), horizontal: horizontal, total: true))
        }
        return out
    }

    static func label(_ v: Double) -> String {
        Int(exactly: v.rounded()).map(String.init) ?? ""
    }
}
