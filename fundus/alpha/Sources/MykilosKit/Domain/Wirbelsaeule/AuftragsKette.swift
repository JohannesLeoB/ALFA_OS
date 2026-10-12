import Foundation

public struct AuftragsKette: Sendable, Identifiable, Equatable {
    public let root: WorkBasketID
    public let projectNumber: String
    public let bestaetigtAm: Date

    public let fortfuehrungen: [WorkBasketID]

    public let auftragswert: Double

    public let einkaufswert: Double

    public let positionenOhneEK: Int

    public let stundenKontingent: Double

    public let positionen: Int

    public var id: String { root.raw }
    public var istFortgefuehrt: Bool { fortfuehrungen.isEmpty == false }

    public var marge: Double? {
        guard positionen > positionenOhneEK else { return nil }
        return auftragswert - einkaufswert
    }

    public var margeProzent: Double? {
        guard let marge, auftragswert > 0 else { return nil }
        return marge / auftragswert * 100
    }

    public var margeVollstaendig: Bool { positionenOhneEK == 0 }

    public init(root: WorkBasketID, projectNumber: String, bestaetigtAm: Date,
                fortfuehrungen: [WorkBasketID] = [], auftragswert: Double = 0,
                einkaufswert: Double = 0, positionenOhneEK: Int = 0,
                stundenKontingent: Double = 0, positionen: Int = 0) {
        self.root = root
        self.projectNumber = projectNumber
        self.bestaetigtAm = bestaetigtAm
        self.fortfuehrungen = fortfuehrungen
        self.auftragswert = auftragswert
        self.einkaufswert = einkaufswert
        self.positionenOhneEK = positionenOhneEK
        self.stundenKontingent = stundenKontingent
        self.positionen = positionen
    }
}

public enum AuftragsKettenRechner {
    public static func ketten(aus koerbe: [WorkBasket]) -> (ketten: [AuftragsKette], verwaist: [WorkBasketID]) {
        let wurzeln = koerbe.filter { $0.status == .bestaetigt }
        let wurzelIDs = Set(wurzeln.map(\.id))

        var anhang: [WorkBasketID: [WorkBasket]] = [:]
        var verwaist: [WorkBasketID] = []
        for korb in koerbe {
            guard let bezug = bezugsWurzel(korb.status) else { continue }
            if wurzelIDs.contains(bezug) {
                anhang[bezug, default: []].append(korb)
            } else {
                verwaist.append(korb.id)
            }
        }

        let ketten = wurzeln
            .sorted { $0.erstellt < $1.erstellt }
            .map { root -> AuftragsKette in
                let folge = (anhang[root.id] ?? []).sorted { $0.erstellt < $1.erstellt }
                let alle = [root] + folge
                return AuftragsKette(
                    root: root.id,
                    projectNumber: root.projectNumber,
                    bestaetigtAm: root.erstellt,
                    fortfuehrungen: folge.map(\.id),
                    auftragswert: alle.reduce(0) { $0 + nettoWert($1) },
                    einkaufswert: alle.reduce(0) { $0 + einkaufsWert($1) },
                    positionenOhneEK: alle.reduce(0) { $0 + positionenOhneEK($1) },
                    stundenKontingent: alle.reduce(0) { $0 + stunden($1) },
                    positionen: alle.reduce(0) { $0 + $1.picks.count })
            }
        return (ketten, verwaist.sorted { $0.raw < $1.raw })
    }

    static func bezugsWurzel(_ status: WorkBasketStatus) -> WorkBasketID? {
        switch status {
        case .nachtrag(let zu), .gutschrift(let zu): return zu
        case .kalkulation, .bestaetigt: return nil
        }
    }

    public static func nettoWert(_ korb: WorkBasket) -> Double {
        korb.picks.reduce(0) { sum, pick in
            sum + (pick.snapshot.vkEinzel ?? 0) * Double(pick.snapshot.quantity)
        }
    }

    public static func einkaufsWert(_ korb: WorkBasket) -> Double {
        korb.picks.reduce(0) { sum, pick in
            sum + (pick.snapshot.ekEinzel ?? 0) * Double(pick.snapshot.quantity)
        }
    }

    public static func positionenOhneEK(_ korb: WorkBasket) -> Int {
        korb.picks.filter { $0.snapshot.ekEinzel == nil }.count
    }

    public static func positionenOhneVK(_ korb: WorkBasket) -> Int {
        korb.picks.filter { $0.snapshot.vkEinzel == nil }.count
    }

    public static func stunden(_ korb: WorkBasket) -> Double {
        StundenkontingentRechner.sum(aus: korb.picks.map {
            (attribute: $0.snapshot.attribute, quantity: $0.snapshot.quantity)
        })
    }

    public static func projektWert(_ ketten: [AuftragsKette]) -> Double {
        ketten.reduce(0) { $0 + $1.auftragswert }
    }

    public static func projektStunden(_ ketten: [AuftragsKette]) -> Double {
        ketten.reduce(0) { $0 + $1.stundenKontingent }
    }
}
