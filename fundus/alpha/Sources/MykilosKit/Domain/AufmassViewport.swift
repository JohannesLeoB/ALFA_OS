import Foundation

public struct Viewport: Equatable, Sendable {
    public var zoom: Double
    public var panX: Double
    public var panY: Double
    public var containerW: Double
    public var containerH: Double
    public let minZoom: Double
    public let maxZoom: Double

    public init(zoom: Double = 1, panX: Double = 0, panY: Double = 0,
                containerW: Double = 0, containerH: Double = 0,
                minZoom: Double = 1, maxZoom: Double = 12) {
        self.zoom = zoom
        self.panX = panX
        self.panY = panY
        self.containerW = containerW
        self.containerH = containerH
        self.minZoom = minZoom
        self.maxZoom = maxZoom
    }

    public mutating func fit() { zoom = minZoom; panX = 0; panY = 0 }

    public var istEingepasst: Bool { zoom <= minZoom && panX == 0 && panY == 0 }

    public mutating func setzeZoom(_ target: Double, pivotX: Double? = nil, pivotY: Double? = nil) {
        let neu = min(max(target, minZoom), maxZoom)
        guard neu != zoom else { return }
        if let px = pivotX, let py = pivotY {
            let f = neu / zoom
            let baseCx = containerW / 2, baseCy = containerH / 2
            let cx = baseCx + panX, cy = baseCy + panY
            panX = (px - f * (px - cx)) - baseCx
            panY = (py - f * (py - cy)) - baseCy
        }
        zoom = neu
        if zoom <= minZoom { panX = 0; panY = 0 }
        klemme()
    }

    public mutating func zoomeUm(_ faktor: Double, pivotX: Double? = nil, pivotY: Double? = nil) {
        setzeZoom(zoom * faktor, pivotX: pivotX, pivotY: pivotY)
    }

    public mutating func verschiebe(dx: Double, dy: Double) {
        guard zoom > minZoom else { return }
        panX += dx; panY += dy
        klemme()
    }

    public mutating func setzePan(x: Double, y: Double) {
        guard zoom > minZoom else { return }
        panX = x; panY = y
        klemme()
    }

    mutating func klemme() {
        let maxX = zoom * containerW / 2
        let maxY = zoom * containerH / 2
        panX = min(max(panX, -maxX), maxX)
        panY = min(max(panY, -maxY), maxY)
    }
}
