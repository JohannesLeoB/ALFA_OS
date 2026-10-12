import Foundation

public struct PlatziertesBild: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, source = "quelle", x, y, width = "breite", height = "hoehe", rotationGrad, gespiegeltH, deckkraft, gesperrt, zIndex }

    public let id: UUID

    public var source: FotoQuelle

    public var x: Double
    public var y: Double

    public var width: Double

    public var height: Double?

    public var rotationGrad: Double
    public var gespiegeltH: Bool
    public var deckkraft: Double

    public var gesperrt: Bool

    public var zIndex: Int

    public init(id: UUID = UUID(), source: FotoQuelle,
                x: Double = 0.5, y: Double = 0.5, width: Double = 0.4, height: Double? = nil,
                rotationGrad: Double = 0, gespiegeltH: Bool = false,
                deckkraft: Double = 1, gesperrt: Bool = false, zIndex: Int = 0) {
        self.id = id
        self.source = source
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotationGrad = rotationGrad
        self.gespiegeltH = gespiegeltH
        self.deckkraft = deckkraft
        self.gesperrt = gesperrt
        self.zIndex = zIndex
    }
}

public enum PlatziertesBildGeometrie {
    public static let minWidth: Double = 0.04

    public static func frame(_ image: PlatziertesBild, aspekt: Double, flaechenAspekt: Double)
    -> (x: Double, y: Double, width: Double, height: Double) {
        let b = max(image.width, minWidth)
        let h = image.height.map { max($0, minWidth) }
            ?? b * max(aspekt, 0.01) * max(flaechenAspekt, 0.01)
        return (image.x - b / 2, image.y - h / 2, b, h)
    }

    public static func trifft(_ image: PlatziertesBild, point: (x: Double, y: Double),
                              aspekt: Double, flaechenAspekt: Double) -> Bool {
        let r = frame(image, aspekt: aspekt, flaechenAspekt: flaechenAspekt)

        let a = max(flaechenAspekt, 0.01)
        let dx = (point.x - image.x) * a
        let dy = point.y - image.y
        let w = -image.rotationGrad * .pi / 180
        let rx = dx * cos(w) - dy * sin(w)
        let ry = dx * sin(w) + dy * cos(w)
        return abs(rx) <= r.width * a / 2 && abs(ry) <= r.height / 2
    }

    public static func obersteTreffer(_ images: [PlatziertesBild], point: (x: Double, y: Double),
                                      aspekt: (UUID) -> Double, flaechenAspekt: Double) -> UUID? {
        images
            .filter { $0.gesperrt == false }
            .sorted { $0.zIndex > $1.zIndex }
            .first { trifft($0, point: point, aspekt: aspekt($0.id), flaechenAspekt: flaechenAspekt) }?
            .id
    }

    public static func naechsterZIndex(_ images: [PlatziertesBild]) -> Int {
        (images.map(\.zIndex).max() ?? 0) + 1
    }

    public static func skaliert(_ image: PlatziertesBild, faktor: Double) -> PlatziertesBild {
        var neu = image
        neu.width = max(image.width * max(faktor, 0.01), minWidth)
        if let h = image.height { neu.height = max(h * max(faktor, 0.01), minWidth) }
        return neu
    }

    public static func verschoben(_ image: PlatziertesBild, dx: Double, dy: Double) -> PlatziertesBild {
        var neu = image
        neu.x = min(max(image.x + dx, 0), 1)
        neu.y = min(max(image.y + dy, 0), 1)
        return neu
    }

    public static func normalisierterWinkel(_ grad: Double) -> Double {
        let g = grad.truncatingRemainder(dividingBy: 360)
        return g < 0 ? g + 360 : g
    }
}
