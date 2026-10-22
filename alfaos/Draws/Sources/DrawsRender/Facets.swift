import DrawingKit
import Foundation
import RealityKit
import simd

enum Space {
    static let metre = 0.001

    static func point(_ p: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3(Float(p.x * metre), Float(p.z * metre), Float(-p.y * metre))
    }

    static func direction(_ d: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3(Float(d.x), Float(d.z), Float(-d.y))
    }

    static func orientation(right: SIMD3<Double>, up: SIMD3<Double>, forward: SIMD3<Double>) -> simd_quatf {
        let r = direction(right), u = direction(up), b = -direction(forward)
        return simd_quatf(simd_float3x3(columns: (r, u, b)))
    }
}

enum Facets {
    static func points(_ part: Part) -> [SIMD3<Double>] {
        Solids.faces(part).flatMap(\.points)
    }

    @MainActor
    static func mesh(_ part: Part, tile: Double) throws -> MeshResource {
        let faces = Solids.faces(part)
        let all = faces.flatMap(\.points)
        guard !all.isEmpty else { throw PhotoError.empty }
        let centroid = all.reduce(SIMD3<Double>.zero, +) / Double(all.count)
        let scale = 1 / max(tile, 1)
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        for face in faces where face.points.count >= 3 {
            let mid = face.points.reduce(SIMD3<Double>.zero, +) / Double(face.points.count)
            var n = simd_normalize(face.normal)
            if simd_dot(n, mid - centroid) < 0 { n = -n }
            let base = UInt32(positions.count)
            let ax = abs(n.x), ay = abs(n.y), az = abs(n.z)
            for p in face.points {
                positions.append(Space.point(p))
                normals.append(Space.direction(n))
                let uv: SIMD2<Double>
                if az >= ax, az >= ay { uv = SIMD2(p.x, p.y) } else if ax >= ay { uv = SIMD2(p.y, p.z) } else { uv = SIMD2(p.x, p.z) }
                uvs.append(SIMD2(Float(uv.x * scale), Float(uv.y * scale)))
            }
            for i in 1..<(face.points.count - 1) {
                let a = face.points[0], b = face.points[i], c = face.points[i + 1]
                let flip = simd_dot(simd_cross(b - a, c - a), n) < 0
                indices += flip ? [base, base + UInt32(i + 1), base + UInt32(i)] : [base, base + UInt32(i), base + UInt32(i + 1)]
            }
        }
        var d = MeshDescriptor(name: part.id)
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        d.primitives = .triangles(indices)
        return try MeshResource.generate(from: [d])
    }
}
