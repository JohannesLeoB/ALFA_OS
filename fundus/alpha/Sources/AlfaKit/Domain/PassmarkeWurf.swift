import Foundation

public enum PassmarkeWurf {
    public static let schwelle: Double = PassmarkeMass.fangzone / PassmarkeMass.rufFenster

    public static let eindeutigkeit: Double = 1.4

    public static func target(vx: Double, vy: Double) -> PassmarkeHeimseite? {
        let tempo = (vx * vx + vy * vy).squareRoot()
        guard tempo >= schwelle else { return nil }
        let ax = abs(vx), ay = abs(vy)
        if ax >= ay * eindeutigkeit { return vx > 0 ? .rechts : .links }
        if ay >= ax * eindeutigkeit { return vy > 0 ? .unten : nil }
        return nil
    }
}
