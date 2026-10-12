import Foundation

public struct PlanPunkt: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double = 0) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct PlanPapierPunkt: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum PlanAchse: CaseIterable, Sendable {
    case x, y, z
    public var einheit: PlanPunkt {
        switch self {
        case .x: PlanPunkt(x: 1, y: 0, z: 0)
        case .y: PlanPunkt(x: 0, y: 1, z: 0)
        case .z: PlanPunkt(x: 0, y: 0, z: 1)
        }
    }
}

public enum PlanProjektion: String, Codable, CaseIterable, Sendable, Identifiable {
    case elevation

    case isometrie

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .elevation: "Elevation"
        case .isometrie: "Isometrie"
        }
    }

    public var symbol: String {
        switch self {
        case .elevation: "square"
        case .isometrie: "cube"
        }
    }
}

public enum PlanProjektor {
    public static let isoWinkel: Double = .pi / 6

    public static func projiziere(_ p: PlanPunkt, projektion: PlanProjektion) -> PlanPapierPunkt {
        switch projektion {
        case .elevation:
            return PlanPapierPunkt(x: p.x, y: p.y)
        case .isometrie:
            let c = cos(isoWinkel), s = sin(isoWinkel)
            return PlanPapierPunkt(x: (p.x - p.z) * c, y: p.y + (p.x + p.z) * s)
        }
    }

    public static func ebenenPunkt(_ papier: PlanPapierPunkt, projektion: PlanProjektion) -> PlanPunkt {
        switch projektion {
        case .elevation:
            return PlanPunkt(x: papier.x, y: papier.y, z: 0)
        case .isometrie:
            let c = cos(isoWinkel), s = sin(isoWinkel)
            let xMinusZ = papier.x / c
            let xPlusZ = papier.y / s
            return PlanPunkt(x: (xMinusZ + xPlusZ) / 2, y: 0, z: (xPlusZ - xMinusZ) / 2)
        }
    }

    public static func achsenSnap(start: PlanPunkt, zeigerPapier: PlanPapierPunkt,
                                  projektion: PlanProjektion) -> PlanPunkt {
        let startPapier = projiziere(start, projektion: projektion)
        let dx = zeigerPapier.x - startPapier.x
        let dy = zeigerPapier.y - startPapier.y
        let achsen: [PlanAchse] = projektion == .elevation ? [.x, .y] : [.x, .y, .z]
        var beste: (achse: PlanAchse, mm: Double, betrag: Double)?
        for achse in achsen {
            let e = achse.einheit
            let ende = projiziere(PlanPunkt(x: start.x + e.x, y: start.y + e.y, z: start.z + e.z),
                                  projektion: projektion)
            let ax = ende.x - startPapier.x, ay = ende.y - startPapier.y
            let len = (ax * ax + ay * ay).squareRoot()
            guard len > 1e-9 else { continue }
            let t = (dx * ax + dy * ay) / len
            let mm = t / len
            let betrag = abs(t)
            if beste == nil || betrag > beste!.betrag { beste = (achse, mm, betrag) }
        }
        guard let b = beste else { return start }
        let e = b.achse.einheit
        return PlanPunkt(x: start.x + e.x * b.mm, y: start.y + e.y * b.mm, z: start.z + e.z * b.mm)
    }

    public static func papierRahmen(_ points: [PlanPunkt], projektion: PlanProjektion) -> PlanPapierRahmen? {
        guard points.isEmpty == false else { return nil }
        var minX = Double.greatestFiniteMagnitude, minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
        for p in points {
            let pp = projiziere(p, projektion: projektion)
            minX = min(minX, pp.x); minY = min(minY, pp.y)
            maxX = max(maxX, pp.x); maxY = max(maxY, pp.y)
        }
        return PlanPapierRahmen(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }
}

public struct PlanPapierRahmen: Equatable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX; self.minY = minY; self.maxX = maxX; self.maxY = maxY
    }

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var mitte: PlanPapierPunkt { PlanPapierPunkt(x: (minX + maxX) / 2, y: (minY + maxY) / 2) }
}
