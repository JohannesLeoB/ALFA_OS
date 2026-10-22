import DrawingKit
import Foundation
import simd

public struct Rig: Sendable, Equatable {
    public var target: SIMD3<Double>
    public var eye: SIMD3<Double>
    public var right: SIMD3<Double>
    public var up: SIMD3<Double>
    public var forward: SIMD3<Double>
    public var fov: Double
    public var distance: Double
    public var ortho = false
    public var scale = 0.0

    public static let margin = 0.1
    static let parallelFov = 5.0
    static let fovRange = 25.0...50.0
    static let fovDefault = 35.0
    static let rounds = 6

    public static func angles(_ view: ViewSpec) -> (azimuth: Double, elevation: Double) {
        switch view.kind {
        case .front: return (0, 0)
        case .back: return (180, 0)
        case .top: return (0, 90)
        case .left: return (90, 0)
        case .right: return (270, 0)
        case .iso, .perspective: return (view.azimuth, view.elevation)
        }
    }

    public static func basis(azimuth: Double, elevation: Double)
        -> (right: SIMD3<Double>, up: SIMD3<Double>, forward: SIMD3<Double>) {
        let a = azimuth * .pi / 180, e = elevation * .pi / 180
        return (SIMD3(cos(a), -sin(a), 0), SIMD3(sin(a) * sin(e), cos(a) * sin(e), cos(e)),
                SIMD3(sin(a) * cos(e), cos(a) * cos(e), -sin(e)))
    }

    public static func fit(points: [SIMD3<Double>], view: ViewSpec, aspect: Double, margin: Double = Rig.margin) -> Rig? {
        guard let first = points.first, aspect > 0, aspect.isFinite else { return nil }
        let (az, el) = angles(view)
        let b = basis(azimuth: az, elevation: el)
        var lo = first, hi = first
        for p in points {
            lo = simd_min(lo, p)
            hi = simd_max(hi, p)
        }
        let radius = simd_length(hi - lo) / 2
        guard radius > 0 else { return nil }
        if view.kind != .perspective {
            var lo2 = SIMD2(Double.infinity, Double.infinity), hi2 = -lo2
            for p in points {
                let q = SIMD2(simd_dot(p, b.right), simd_dot(p, b.up))
                lo2 = simd_min(lo2, q); hi2 = simd_max(hi2, q)
            }
            let c = (lo + hi) / 2, mid = (lo2 + hi2) / 2
            let target = c + b.right * (mid.x - simd_dot(c, b.right)) + b.up * (mid.y - simd_dot(c, b.up))
            let half = max((hi2.y - lo2.y) / 2, (hi2.x - lo2.x) / 2 / aspect) / (1 - margin)
            let distance = radius * 4
            return Rig(target: target, eye: target - b.forward * distance, right: b.right, up: b.up, forward: b.forward,
                       fov: parallelFov, distance: distance, ortho: true, scale: max(half, 1))
        }
        let fov = view.distance.map { min(fovRange.upperBound, max(fovRange.lowerBound, 2 * atan(radius / $0) * 180 / .pi)) } ?? fovDefault
        let tanV = tan(fov * .pi / 360), tanH = tanV * aspect
        let usable = 1 - margin
        var target = (lo + hi) / 2
        var distance = radius * 4
        for _ in 0..<rounds {
            var need = 0.0
            for p in points {
                let rel = p - target
                let r = simd_dot(rel, b.right), u = simd_dot(rel, b.up), f = simd_dot(rel, b.forward)
                need = max(need, abs(r) / (usable * tanH) - f, abs(u) / (usable * tanV) - f)
            }
            distance = max(need, radius * 0.5)
            var minX = Double.infinity, maxX = -Double.infinity, minY = Double.infinity, maxY = -Double.infinity
            for p in points {
                let rel = p - target
                let depth = simd_dot(rel, b.forward) + distance
                guard depth > 1e-6 else { continue }
                let x = simd_dot(rel, b.right) / (depth * tanH), y = simd_dot(rel, b.up) / (depth * tanV)
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
            guard minX.isFinite, minY.isFinite else { break }
            let shiftX = (minX + maxX) / 2 * tanH * distance, shiftY = (minY + maxY) / 2 * tanV * distance
            target += b.right * shiftX
            target += b.up * shiftY
        }
        return Rig(target: target, eye: target - b.forward * distance, right: b.right, up: b.up, forward: b.forward,
                   fov: fov, distance: distance)
    }

    public func project(_ p: SIMD3<Double>, aspect: Double) -> SIMD2<Double> {
        let rel = p - target
        if ortho { return SIMD2(simd_dot(rel, right) / (scale * aspect), simd_dot(rel, up) / scale) }
        let depth = simd_dot(rel, forward) + distance
        let tanV = tan(fov * .pi / 360)
        return SIMD2(simd_dot(rel, right) / (depth * tanV * aspect), simd_dot(rel, up) / (depth * tanV))
    }
}
