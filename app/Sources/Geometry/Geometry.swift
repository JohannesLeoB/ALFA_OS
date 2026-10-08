import Foundation
import ALFAcolorCore

/// Measurement units. The base unit is the point (pt, 1/72 inch), as in Apple layouts and InDesign.
public enum Unit: String, Codable, Sendable, CaseIterable {
    case pt, px, mm
    /// Conversion from points. px depends on the scale factor of the device (@1x, @2x, @3x).
    public func fromPoints(_ v: Double, scale: Double = 1) -> Double {
        switch self { case .pt: v; case .px: v * scale; case .mm: v * 25.4 / 72 }
    }
    public func toPoints(_ v: Double, scale: Double = 1) -> Double {
        switch self { case .pt: v; case .px: v / scale; case .mm: v * 72 / 25.4 }
    }
}

/// A device or window as a frame size. The values are templates: check them against the Apple docs before use.
/// `name` is a key of the string catalog.
public struct Device: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var width: Double          // points
    public var height: Double         // points
    public var scales: [Double]       // pixels per point, for example [2]
    public var safeArea: (top: Double, left: Double, bottom: Double, right: Double) { (safeTop, safeLeft, safeBottom, safeRight) }
    public var safeTop = 0.0, safeLeft = 0.0, safeBottom = 0.0, safeRight = 0.0
    public init(id: String, name: String, width: Double, height: Double, scales: [Double]) {
        self.id = id; self.name = name; self.width = width; self.height = height; self.scales = scales
    }
    public func pixels(at scale: Double) -> (w: Double, h: Double) { (width * scale, height * scale) }
    /// The device turned by 90 degrees. The id ends in `-landscape` or `-portrait` to match the new
    /// orientation. Turning a rotated device back gives the original id and name.
    public var rotated: Device {
        var d = self
        (d.width, d.height) = (height, width)
        let suffixes = ["-landscape", "-portrait"]
        if let suffix = suffixes.first(where: { id.hasSuffix($0) }) {
            d.id = String(id.dropLast(suffix.count))
        } else {
            d.id += d.width >= d.height ? "-landscape" : "-portrait"
        }
        let nameSuffix = ".rotated"
        d.name = name.hasSuffix(nameSuffix) ? String(name.dropLast(nameSuffix.count)) : name + nameSuffix
        return d
    }

    /// Start list. Source: common default resolutions. Check each line against the Apple docs before release.
    public static let presets: [Device] = [
        Device(id: "mbp14", name: "device.mbp14", width: 1512, height: 982, scales: [2]),
        Device(id: "mac-window", name: "device.macWindow", width: 1280, height: 800, scales: [2]),
        Device(id: "ipad-11", name: "device.ipad11", width: 1180, height: 820, scales: [2]),
        Device(id: "iphone", name: "device.iphone", width: 393, height: 852, scales: [3])
    ]
}

/// Column grid as in InDesign: columns, gutter, margins. Plus a baseline grid.
public struct ColumnGrid: Codable, Hashable, Sendable {
    public var columns: Int
    public var gutter: Double
    public var marginLeft: Double, marginRight: Double, marginTop: Double, marginBottom: Double
    public var baseline: Double        // 0 = off
    public init(columns: Int, gutter: Double, margin: Double, baseline: Double = 0) {
        self.columns = max(1, columns); self.gutter = gutter
        marginLeft = margin; marginRight = margin; marginTop = margin; marginBottom = margin; self.baseline = baseline
    }
    /// The columns as rectangles inside a frame.
    public func columnRects(in frame: Rect) -> [Rect] {
        let inner = frame.w - marginLeft - marginRight
        let cw = (inner - gutter * Double(columns - 1)) / Double(columns)
        return (0..<columns).map { i in
            Rect(x: frame.x + marginLeft + Double(i) * (cw + gutter), y: frame.y + marginTop, w: cw, h: frame.h - marginTop - marginBottom)
        }
    }
    /// Width across n columns including the gutters between them.
    public func span(_ n: Int, in frame: Rect) -> Double {
        let r = columnRects(in: frame); let k = min(max(n, 1), r.count)
        return r[k - 1].maxX - r[0].x
    }
    /// Y positions of the baselines in the frame.
    public func baselines(in frame: Rect) -> [Double] {
        guard baseline > 0 else { return [] }
        return Array(stride(from: frame.y + marginTop, through: frame.maxY - marginBottom, by: baseline))
    }
}

/// Snap to a grid. A step of 8 gives the 8 point grid.
public func snap(_ v: Double, step: Double) -> Double { step > 0 ? (v / step).rounded() * step : v }

/// Aspect ratio reduced, for example 1512 x 982 -> 756:491.
public func aspectRatio(_ w: Int, _ h: Int) -> (Int, Int) {
    func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
    let g = gcd(abs(w), abs(h)); return g == 0 ? (w, h) : (w / g, h / g)
}

/// Known ratios for the inspector (golden ratio, DIN, photo, video).
public enum NamedRatio: String, CaseIterable, Sendable {
    case square = "1:1", photo = "3:2", screen = "4:3", video = "16:9", din = "1:√2", golden = "1:φ"
    public var value: Double {
        switch self { case .square: 1; case .photo: 1.5; case .screen: 4.0 / 3; case .video: 16.0 / 9; case .din: 2.0.squareRoot(); case .golden: (1 + 5.0.squareRoot()) / 2 }
    }
}
