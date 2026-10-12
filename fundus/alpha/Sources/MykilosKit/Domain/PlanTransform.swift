import Foundation

public struct PlanViewPunkt: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct PlanTransform: Equatable, Sendable {
    public var frame: PlanPapierRahmen
    public var containerW: Double
    public var containerH: Double
    public var zoom: Double
    public var panX: Double
    public var panY: Double

    public var rand: Double

    public init(frame: PlanPapierRahmen, containerW: Double, containerH: Double,
                zoom: Double = 1, panX: Double = 0, panY: Double = 0, rand: Double = 48) {
        self.frame = frame
        self.containerW = containerW
        self.containerH = containerH
        self.zoom = zoom
        self.panX = panX
        self.panY = panY
        self.rand = rand
    }

    public var basisMassstab: Double {
        let nutzbarW = max(containerW - 2 * rand, 1)
        let nutzbarH = max(containerH - 2 * rand, 1)
        let bw = max(frame.width, 1)
        let bh = max(frame.height, 1)
        return max(min(nutzbarW / bw, nutzbarH / bh), 1e-6)
    }

    public var effektiverMassstab: Double { basisMassstab * zoom }

    public func papierZuView(_ p: PlanPapierPunkt) -> PlanViewPunkt {
        let s = effektiverMassstab
        let m = frame.mitte
        let cx = containerW / 2 + panX
        let cy = containerH / 2 + panY
        return PlanViewPunkt(x: cx + (p.x - m.x) * s,
                             y: cy - (p.y - m.y) * s)
    }

    public func viewZuPapier(_ v: PlanViewPunkt) -> PlanPapierPunkt {
        let s = effektiverMassstab
        let m = frame.mitte
        let cx = containerW / 2 + panX
        let cy = containerH / 2 + panY
        return PlanPapierPunkt(x: m.x + (v.x - cx) / s,
                               y: m.y - (v.y - cy) / s)
    }
}
