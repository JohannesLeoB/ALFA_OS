import Foundation
import SetzkastenCore

/// Maßeinheiten. Grundeinheit ist der Punkt (pt, 1/72 Zoll), wie in Apple-Layouts und InDesign.
public enum Unit: String, Codable, Sendable, CaseIterable {
    case pt, px, mm
    /// Umrechnung aus Punkten. px hängt vom Skalierungsfaktor des Geräts ab (@1x, @2x, @3x).
    public func fromPoints(_ v: Double, scale: Double = 1) -> Double {
        switch self { case .pt: v; case .px: v * scale; case .mm: v * 25.4 / 72 }
    }
    public func toPoints(_ v: Double, scale: Double = 1) -> Double {
        switch self { case .pt: v; case .px: v / scale; case .mm: v * 72 / 25.4 }
    }
}

/// Ein Gerät oder Fenster als Rahmengröße. Werte sind Vorlagen: vor Gebrauch an Apple-Doku prüfen.
public struct Device: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var width: Double          // Punkte
    public var height: Double         // Punkte
    public var scales: [Double]       // Pixel je Punkt, z. B. [2]
    public var safeArea: (top: Double, left: Double, bottom: Double, right: Double) { (safeTop, safeLeft, safeBottom, safeRight) }
    public var safeTop = 0.0, safeLeft = 0.0, safeBottom = 0.0, safeRight = 0.0
    public init(id: String, name: String, width: Double, height: Double, scales: [Double]) {
        self.id = id; self.name = name; self.width = width; self.height = height; self.scales = scales
    }
    public func pixels(at scale: Double) -> (w: Double, h: Double) { (width * scale, height * scale) }
    public var rotated: Device { var d = self; d.id += "-quer"; d.name += " quer"; (d.width, d.height) = (height, width); return d }

    /// Startliste. Herkunft: übliche Standardauflösungen; jede Zeile vor Auslieferung gegen Apple-Doku prüfen.
    public static let presets: [Device] = [
        Device(id: "mbp14", name: "MacBook Pro 14 Zoll (Standard)", width: 1512, height: 982, scales: [2]),
        Device(id: "mac-fenster", name: "Mac-Fenster", width: 1280, height: 800, scales: [2]),
        Device(id: "ipad-11", name: "iPad 11 Zoll quer", width: 1180, height: 820, scales: [2]),
        Device(id: "iphone", name: "iPhone 6,1 Zoll", width: 393, height: 852, scales: [3])
    ]
}

/// Spaltenraster wie in InDesign: Spalten, Steg, Ränder. Dazu ein Grundlinienraster.
public struct ColumnGrid: Codable, Hashable, Sendable {
    public var columns: Int
    public var gutter: Double
    public var marginLeft: Double, marginRight: Double, marginTop: Double, marginBottom: Double
    public var baseline: Double        // 0 = aus
    public init(columns: Int, gutter: Double, margin: Double, baseline: Double = 0) {
        self.columns = max(1, columns); self.gutter = gutter
        marginLeft = margin; marginRight = margin; marginTop = margin; marginBottom = margin; self.baseline = baseline
    }
    /// Die Spalten als Rechtecke innerhalb eines Rahmens.
    public func columnRects(in frame: Rect) -> [Rect] {
        let inner = frame.w - marginLeft - marginRight
        let cw = (inner - gutter * Double(columns - 1)) / Double(columns)
        return (0..<columns).map { i in
            Rect(x: frame.x + marginLeft + Double(i) * (cw + gutter), y: frame.y + marginTop, w: cw, h: frame.h - marginTop - marginBottom)
        }
    }
    /// Breite über n Spalten inklusive der Stege dazwischen.
    public func span(_ n: Int, in frame: Rect) -> Double {
        let r = columnRects(in: frame); let k = min(max(n, 1), r.count)
        return r[k - 1].maxX - r[0].x
    }
    /// Y-Positionen der Grundlinien im Rahmen.
    public func baselines(in frame: Rect) -> [Double] {
        guard baseline > 0 else { return [] }
        return Array(stride(from: frame.y + marginTop, through: frame.maxY - marginBottom, by: baseline))
    }
}

/// Einrasten auf ein Raster. step 8 ergibt das 8er-Raster.
public func snap(_ v: Double, step: Double) -> Double { step > 0 ? (v / step).rounded() * step : v }

/// Seitenverhältnis gekürzt, z. B. 1512 x 982 -> 756:491.
public func aspectRatio(_ w: Int, _ h: Int) -> (Int, Int) {
    func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
    let g = gcd(abs(w), abs(h)); return g == 0 ? (w, h) : (w / g, h / g)
}

/// Bekannte Verhältnisse für den Inspektor (Goldener Schnitt, DIN, Foto, Video).
public enum NamedRatio: String, CaseIterable, Sendable {
    case square = "1:1", photo = "3:2", screen = "4:3", video = "16:9", din = "1:√2", golden = "1:φ"
    public var value: Double {
        switch self { case .square: 1; case .photo: 1.5; case .screen: 4.0 / 3; case .video: 16.0 / 9; case .din: 2.0.squareRoot(); case .golden: (1 + 5.0.squareRoot()) / 2 }
    }
}
