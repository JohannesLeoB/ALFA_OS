import Foundation

public struct WolkenPlatz: Equatable, Sendable {
    public let index: Int
    public let versatz: HubVektor

    public init(index: Int, versatz: HubVektor) {
        self.index = index
        self.versatz = versatz
    }
}

public enum WerkzeugWolke {
    public static let width: Double = 520
    public static let height: Double = 432

    public static let mindestAbstand: Double = 58

    public static let ringe: [(radius: Double, plaetze: Int)] = [
        (radius: 0, plaetze: 1),
        (radius: 84, plaetze: 5),
        (radius: 168, plaetze: 8)
    ]

    public static var fassungsvermoegen: Int { ringe.reduce(0) { $0 + $1.plaetze } }

    public static var aeussererRadius: Double { ringe.map(\.radius).max() ?? 0 }

    public static func plaetze(count: Int) -> [WolkenPlatz] {
        guard count > 0 else { return [] }
        var result: [WolkenPlatz] = []
        var offen = min(count, fassungsvermoegen)
        var index = 0

        for (ringNr, ring) in ringe.enumerated() where offen > 0 {
            let hier = min(offen, ring.plaetze)
            offen -= hier

            if ring.radius == 0 {
                result.append(WolkenPlatz(index: index, versatz: .null))
                index += 1
                continue
            }

            let schritt = 2 * Double.pi / Double(hier)
            let drehung = schritt / 2 * Double(ringNr)
            for i in 0..<hier {
                let angle = drehung + Double(i) * schritt
                result.append(WolkenPlatz(
                    index: index,
                    versatz: HubVektor(dx: cos(angle) * ring.radius,
                                       dy: sin(angle) * ring.radius)))
                index += 1
            }
        }
        return result
    }

    public static func geklemmteMitte(hub: HubPunkt, in surface: HubFlaeche) -> HubPunkt {
        let halbBreite = width / 2
        let halbHoehe = height / 2

        let x: Double
        if surface.width < width {
            x = surface.width / 2
        } else {
            x = min(max(hub.x, halbBreite), surface.width - halbBreite)
        }

        let y: Double
        if surface.height < height {
            y = surface.height / 2
        } else {
            y = min(max(hub.y, halbHoehe), surface.height - halbHoehe)
        }
        return HubPunkt(x: x, y: y)
    }

    public static let hoverMassstab: Double = 1.45

    public static let hoverReichweite: Double = 132

    public static func massstab(fuer index: Int,
                                ueber: Int?,
                                plaetze: [WolkenPlatz]) -> Double {
        guard let ueber,
              let a = plaetze.first(where: { $0.index == index })?.versatz,
              let b = plaetze.first(where: { $0.index == ueber })?.versatz
        else { return 1.0 }

        let spacing = ((a.dx - b.dx) * (a.dx - b.dx) + (a.dy - b.dy) * (a.dy - b.dy)).squareRoot()
        guard spacing < hoverReichweite else { return 1.0 }

        let naehe = 1 - spacing / hoverReichweite
        return 1 + (hoverMassstab - 1) * naehe
    }

    public static func kleinsterAbstand(_ plaetze: [WolkenPlatz]) -> Double {
        guard plaetze.count > 1 else { return .infinity }
        var kleinster = Double.infinity
        for i in 0..<plaetze.count {
            for j in (i + 1)..<plaetze.count {
                let a = plaetze[i].versatz, b = plaetze[j].versatz
                let d = ((a.dx - b.dx) * (a.dx - b.dx) + (a.dy - b.dy) * (a.dy - b.dy)).squareRoot()
                kleinster = min(kleinster, d)
            }
        }
        return kleinster
    }
}
