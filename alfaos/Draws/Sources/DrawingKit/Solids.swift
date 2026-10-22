import Foundation

public struct SolidFace: Sendable {
    public var normal: SIMD3<Double>
    public var points: [SIMD3<Double>]
}

public enum Solids {
    public static func faces(_ part: Part) -> [SolidFace] {
        Projection.quads(part).map { face in
            SolidFace(normal: SIMD3(face.0.0, face.0.1, face.0.2), points: face.1.map { SIMD3($0.0, $0.1, $0.2) })
        }
    }
}
